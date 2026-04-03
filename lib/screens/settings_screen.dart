import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../services/sleep_tracking_service.dart';
import 'paywall_screen.dart';
import 'login_screen.dart';

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
  int _devTapCount = 0;
  DateTime? _lastDevTap;

  // Ayar değerleri
  bool _notificationsEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);

  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('baby_name') ?? '';
      _notificationsEnabled = prefs.getBool('notifications') ?? false;
      int remHour = prefs.getInt('rem_hour') ?? 21;
      int remMinute = prefs.getInt('rem_minute') ?? 0;
      _reminderTime = TimeOfDay(hour: remHour, minute: remMinute);
    });
  }

  Future<void> _saveBabyName() async {
    final name = _nameController.text.trim();
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
        await NotificationService().scheduleSleepReminder(_reminderTime);
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
      await NotificationService().scheduleSleepReminder(time);
    }
  }

  Future<void> _updateLang(int val) async {
    await _loc.setLanguage(val);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
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

            // ─── Logo + Başlık + Dil Seçimi ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      final now = DateTime.now();
                      if (_lastDevTap != null && now.difference(_lastDevTap!).inSeconds > 3) {
                        _devTapCount = 0;
                      }
                      _lastDevTap = now;
                      _devTapCount++;
                      if (_devTapCount >= 5) {
                        _devTapCount = 0;
                        SubscriptionService().toggleDebugPremium();
                        setState(() {});
                        final isOn = SubscriptionService().isDebugPremium;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isOn ? '🔓 Test Premium: AÇIK' : '🔒 Test Premium: KAPALI'),
                            backgroundColor: isOn ? Colors.green : Colors.orange,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Container(
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
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sleepora', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
                      Text(_loc.t('AppSubtitle'), style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── Premium Abonelik ───
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
                    gradient: SubscriptionService().isPremium
                        ? const LinearGradient(colors: [Color(0xFF1A3D0E), Color(0xFF0D2818)])
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF2A1060), Color(0xFF4C1D95), Color(0xFF3B1F8C)],
                          ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: SubscriptionService().isPremium
                          ? AppColors.green.withValues(alpha:0.3)
                          : const Color(0xFF8B5CF6).withValues(alpha:0.4),
                    ),
                    boxShadow: SubscriptionService().isPremium
                        ? null
                        : [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha:0.15), blurRadius: 16, offset: const Offset(0, 4))],
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
                                gradient: SubscriptionService().isPremium
                                    ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                                    : const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA), Color(0xFF7C3AED)],
                                      ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: SubscriptionService().isPremium
                                    ? null
                                    : [BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha:glow), blurRadius: 14, spreadRadius: 1)],
                              ),
                              child: Icon(
                                SubscriptionService().isPremium
                                    ? Icons.check_circle_rounded
                                    : Icons.diamond_rounded,
                                color: Colors.white,
                                size: 26,
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
                            Text(
                              SubscriptionService().isPremium ? _loc.t('PremiumActive') : 'Sleepora Plus',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              SubscriptionService().isPremium ? _loc.t('AllUnlocked') : _loc.t('UnlockAllFeatures'),
                              style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      if (!SubscriptionService().isPremium)
                        Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha:0.5), size: 24),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Hesap (Account) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _auth.isLoggedIn ? _buildProfilePanel() : _buildLoginPrompt(),
            ),

            // ─── Uyku İstatistikleri (sadece giriş yapılmışsa) ───
            if (_auth.isLoggedIn) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SleepStatsCard(),
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
                      icon: Icons.notifications_active_rounded,
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
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha:0.02),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(_loc.t('ReminderTime'), style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 13, fontWeight: FontWeight.w500)),
                                  GestureDetector(
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: _reminderTime,
                                        builder: (context, child) => Theme(
                                          data: ThemeData.dark().copyWith(
                                            colorScheme: ColorScheme.dark(
                                              primary: AppColors.purple,
                                              onPrimary: Colors.white,
                                              surface: const Color(0xFF1A1025),
                                              onSurface: Colors.white,
                                            ),
                                          ),
                                          child: child!,
                                        ),
                                      );
                                      if (time != null) {
                                        setState(() => _reminderTime = time);
                                        _saveReminderTime(time);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha:0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _reminderTime.format(context),
                                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                      ),
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
                      faIcon: FontAwesomeIcons.solidStar,
                      iconColor: const Color(0xFFFFD700),
                      bgColor: const Color(0xFF3D3200),
                      label: _loc.t('RateApp'),
                      onTap: () async {
                        final uri = Uri.parse('https://apps.apple.com/app/id6745027461');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    _RowDivider(),
                    _ContactRow(
                      faIcon: FontAwesomeIcons.instagram,
                      iconColor: const Color(0xFFE1306C),
                      bgColor: const Color(0xFF3D0E1E),
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
                      iconColor: const Color(0xFFFF0000),
                      bgColor: const Color(0xFF3D0A0A),
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
                      faIcon: FontAwesomeIcons.envelope,
                      iconColor: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFF1E0E3D),
                      label: _loc.t('ContactFeed'),
                      onTap: () async {
                        final uri = Uri.parse('mailto:destek@sleepora.com?subject=Sleepora%20Geri%20Bildirim');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                    _RowDivider(),
                    _ContactRow(
                      faIcon: FontAwesomeIcons.shieldHalved,
                      iconColor: const Color(0xFF60A5FA),
                      bgColor: const Color(0xFF0F2440),
                      label: _loc.t('PrivacyPolicy'),
                      onTap: () async {
                        final uri = Uri.parse('https://enginerdemx-lab.github.io/bebek-uykusu-app/privacy-policy.html');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

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

  void _showEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    bool _saving = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF1A1025),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            _loc.t('EditNameTitle'),
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_loc.t('BtnCancel'), style: const TextStyle(color: Colors.white38)),
            ),
            TextButton(
              onPressed: _saving ? null : () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                setLocal(() => _saving = true);
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
                _saving ? '...' : _loc.t('BtnSave'),
                style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
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
            child: const Text('Çıkış Yap', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
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
              content: Text('Hata: $e'),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }
}

// ─── Toggle Ayar Satırı ───
class _SettingToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingToggleRow({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
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
  final Color bgColor;
  final String label;
  final VoidCallback onTap;
  const _ContactRow({
    this.icon,
    this.faIcon,
    required this.iconColor,
    required this.bgColor,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || faIcon != null);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: faIcon != null
                    ? FaIcon(faIcon!, color: iconColor, size: 18)
                    : Icon(icon!, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha:0.2), size: 22),
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
  const _SleepStatsCard();

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
              child: _WeekBarChart(stats: _stats!, formatDuration: _formatDuration, dayLabel: _dayLabel),
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
                ],
              ),
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

// ─── 7 Günlük Bar Grafik ───
class _WeekBarChart extends StatelessWidget {
  final WeeklyStats stats;
  final String Function(int) formatDuration;
  final String Function(int) dayLabel;

  const _WeekBarChart({
    required this.stats,
    required this.formatDuration,
    required this.dayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final maxMin = stats.days.fold(0, (m, d) => math.max(m, d.totalMinutes));
    final today = DateTime.now();

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final day = stats.days[i];
          final fraction = maxMin > 0 ? day.totalMinutes / maxMin : 0.0;
          final barHeight = (fraction * 52).clamp(4.0, 52.0);
          final isEmpty = day.totalMinutes == 0;
          final isToday = day.date ==
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

          // Haftanın günü (1=Pzt, 7=Paz)
          final dt = DateTime.parse('${day.date} 00:00:00');
          final wdLabel = dayLabel(dt.weekday);

          return Expanded(
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
                        ? Colors.white.withValues(alpha: 0.07)
                        : isToday
                            ? AppColors.purple
                            : AppColors.purple.withValues(alpha: 0.55),
                    boxShadow: isEmpty
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.purple.withValues(alpha: 0.3),
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
                    color: isToday
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.35),
                    fontSize: 9,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
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

            // ─── İçerik ───
            Padding(
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
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
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
                    fontSize: 11,
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
