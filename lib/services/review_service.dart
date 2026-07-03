import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'localization_service.dart';

class ReviewService {
  static const String _hasRatedKey = 'has_rated';
  // İlk yorum isteğinin gösterildiği an — ücretli kullanıcının 24 saatlik
  // ikinci isteği bu zamana göre hesaplanır.
  static const String _firstPromptAtKey = 'review_first_prompt_at';
  // Ücretli kullanıcıya 24 saat sonraki ikinci istek gösterildi mi?
  static const String _paidSecondDoneKey = 'review_paid_second_done';

  // App Store yorum sayfası (id6745027461 → doğrudan "yorum yaz" ekranı).
  static const String _appStoreReviewUrl =
      'https://apps.apple.com/app/id6745027461?action=write-review';

  // Google Play uygulama kimliği (Android'de değerlendirme buraya yönlenir).
  static const String _androidPackage = 'com.bebekuyku.app';

  /// Mağaza listeleme sayfasını doğrudan açar (Ayarlar'daki "Uygulamayı
  /// Değerlendir" butonu). Platforma göre Play Store / App Store.
  static Future<void> openStoreListing() => _openStoreReview();

  /// Kullanıcı puanladı — bir daha hiç gösterme.
  static Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRatedKey, true);
  }

  /// Kullanıcı "Şimdi Değil" dedi. Ek işlem gerekmez: ücretsiz kullanıcıya
  /// tekrar gösterilmez, ücretli kullanıcıya 24 saat sonra bir kez daha sorulur.
  static Future<void> dismissReview() async {}

  /// Mağaza yorum sayfasını açar — platforma göre doğru mağazaya yönlendirir.
  /// Android → Google Play, iOS → App Store.
  static Future<void> _openStoreReview() async {
    if (Platform.isAndroid) {
      // Önce Play Store uygulamasını doğrudan aç (market://), yoksa tarayıcı.
      final market = Uri.parse('market://details?id=$_androidPackage');
      final web = Uri.parse(
          'https://play.google.com/store/apps/details?id=$_androidPackage');
      try {
        if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
      try {
        await launchUrl(web, mode: LaunchMode.externalApplication);
      } catch (_) {}
      return;
    }

    // iOS / diğer → App Store yorum sayfası.
    final uri = Uri.parse(_appStoreReviewUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Yorum pop-up'ını göster.
  ///
  /// Akış:
  ///   • İlk açılış → herkese hemen göster.
  ///   • Ücretli (premium) kullanıcı → ilk istekten 24 saat sonra bir kez daha.
  ///   • Zaten puanladıysa hiç gösterme.
  static Future<void> showReviewDialog(
    BuildContext context, {
    bool isPremium = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // Zaten puanladıysa hiçbir şey yapma.
    if (prefs.getBool(_hasRatedKey) ?? false) return;

    final now = DateTime.now();
    final firstPromptStr = prefs.getString(_firstPromptAtKey);

    bool show = false;
    if (firstPromptStr == null) {
      // İlk açılış — herkese hemen göster ve zamanı kaydet.
      await prefs.setString(_firstPromptAtKey, now.toIso8601String());
      show = true;
    } else if (isPremium) {
      // Ücretli kullanıcı — ilk istekten 24 saat sonra bir kez daha.
      final firstPrompt = DateTime.tryParse(firstPromptStr);
      final secondDone = prefs.getBool(_paidSecondDoneKey) ?? false;
      if (!secondDone &&
          firstPrompt != null &&
          now.difference(firstPrompt).inHours >= 24) {
        await prefs.setBool(_paidSecondDoneKey, true);
        show = true;
      }
    }

    if (!show) return;
    if (!context.mounted) return;

    await _present(context);
  }

  /// Puanlanmadıysa diyaloğu doğrudan gösterir — onboarding'de "AHA anından
  /// sonra" ve "onboarding sonunda" çağrılır. İlk istek zamanını da işaretler
  /// ki ana ekran ayrıca tekrar sormasın.
  static Future<void> showOnboardingPrompt(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_hasRatedKey) ?? false) return;
    if (prefs.getString(_firstPromptAtKey) == null) {
      await prefs.setString(
          _firstPromptAtKey, DateTime.now().toIso8601String());
    }
    if (!context.mounted) return;
    await _present(context);
  }

  static Future<void> _present(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
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
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Üst glow efekti
                  Positioned(
                    top: -40,
                    left: -20,
                    right: -20,
                    height: 120,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF7C3AED).withValues(alpha: 0.35),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App icon — camsı çerçeve içinde
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/logo.jpg',
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // 5 yıldız
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (i) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(
                                Icons.star_rounded,
                                size: 22,
                                color: const Color(0xFFFFD700).withValues(alpha: 0.95),
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          LocalizationService().t('ReviewTitle'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          LocalizationService().t('ReviewDesc'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13.5,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 26),
                        // Puanla butonu — gradient + glow
                        GestureDetector(
                          onTap: () async {
                            await markAsRated();
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _openStoreReview();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.55),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                LocalizationService().t('ReviewRate'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Şimdi değil — camsı ikinci buton
                        GestureDetector(
                          onTap: () {
                            dismissReview();
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                LocalizationService().t('ReviewLater'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
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
      ),
    );
  }
}
