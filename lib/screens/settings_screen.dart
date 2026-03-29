import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../services/localization_service.dart';
import 'paywall_screen.dart';

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
  bool _autoStopEnabled = false;
  bool _fadeOutEnabled = true;
  bool _backgroundPlayEnabled = true;
  bool _notificationsEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 21, minute: 0);

  @override
  void initState() {
    super.initState();
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('baby_name') ?? '';
      _autoStopEnabled = prefs.getBool('auto_stop') ?? false;
      _fadeOutEnabled = prefs.getBool('fade_out') ?? true;
      _backgroundPlayEnabled = prefs.getBool('bg_play') ?? true;
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

            // ─── Oynatma Ayarları (Accordion) ───
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
                    title: Text(_loc.t('PlaybackTitle'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    iconColor: Colors.white,
                    collapsedIconColor: Colors.white.withValues(alpha:0.5),
                    children: [
                      _SettingToggleRow(
                        icon: Icons.timer_off_rounded,
                        iconColor: const Color(0xFFFF6B6B),
                        bgColor: const Color(0xFF3D1515),
                        label: _loc.t('StopTimer'),
                        subtitle: _loc.t('StopTimerSub'),
                        value: _autoStopEnabled,
                        onChanged: (v) {
                          setState(() => _autoStopEnabled = v);
                          _toggleSetting('auto_stop', v);
                        },
                      ),
                      _RowDivider(),
                      _SettingToggleRow(
                        icon: Icons.volume_down_rounded,
                        iconColor: const Color(0xFF60A5FA),
                        bgColor: const Color(0xFF0F2440),
                        label: _loc.t('FadeOut'),
                        subtitle: _loc.t('FadeOutSub'),
                        value: _fadeOutEnabled,
                        onChanged: (v) {
                          setState(() => _fadeOutEnabled = v);
                          _toggleSetting('fade_out', v);
                        },
                      ),
                      _RowDivider(),
                      _SettingToggleRow(
                        icon: Icons.phonelink_lock_rounded,
                        iconColor: const Color(0xFF34D399),
                        bgColor: const Color(0xFF0D2818),
                        label: _loc.t('BackgroundPlay'),
                        subtitle: _loc.t('BackgroundPlaySub'),
                        value: _backgroundPlayEnabled,
                        onChanged: (v) {
                          setState(() => _backgroundPlayEnabled = v);
                          _toggleSetting('bg_play', v);
                        },
                      ),
                      _RowDivider(),
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
                                color: Colors.white.withValues(alpha:0.02),
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
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFFFFD700),
                      bgColor: const Color(0xFF3D3200),
                      label: _loc.t('RateApp'),
                      onTap: () {},
                    ),
                    _RowDivider(),
                    _ContactRow(
                      icon: Icons.camera_alt_rounded,
                      iconColor: const Color(0xFFE1306C),
                      bgColor: const Color(0xFF3D0E1E),
                      label: _loc.t('FollowInsta'),
                      onTap: () {},
                    ),
                    _RowDivider(),
                    _ContactRow(
                      icon: Icons.play_circle_filled_rounded,
                      iconColor: const Color(0xFFFF0000),
                      bgColor: const Color(0xFF3D0A0A),
                      label: _loc.t('YouTubeChannel'),
                      onTap: () {},
                    ),
                    _RowDivider(),
                    _ContactRow(
                      icon: Icons.mail_rounded,
                      iconColor: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFF1E0E3D),
                      label: _loc.t('ContactFeed'),
                      onTap: () {},
                    ),
                    _RowDivider(),
                    _ContactRow(
                      icon: Icons.privacy_tip_rounded,
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
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String label;
  final VoidCallback onTap;
  const _ContactRow({required this.icon, required this.iconColor, required this.bgColor, required this.label, required this.onTap});

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
              child: Icon(icon, color: iconColor, size: 20),
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
