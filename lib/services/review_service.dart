import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'localization_service.dart';

class ReviewService {
  static const String _firstLaunchKey = 'first_launch_date';
  static const String _lastDismissedKey = 'review_last_dismissed';
  static const String _hasRatedKey = 'has_rated';
  static const int _daysBeforeFirstPrompt = 3;
  static const int _daysAfterDismiss = 10;

  /// Yorum pop-up'ı gösterilmeli mi kontrol et
  static Future<bool> shouldShowReviewPrompt() async {
    final prefs = await SharedPreferences.getInstance();

    // Zaten puanladıysa gösterme
    if (prefs.getBool(_hasRatedKey) ?? false) return false;

    final now = DateTime.now();

    // İlk açılış tarihini kaydet
    final firstLaunchStr = prefs.getString(_firstLaunchKey);
    if (firstLaunchStr == null) {
      await prefs.setString(_firstLaunchKey, now.toIso8601String());
      return false;
    }

    final firstLaunch = DateTime.parse(firstLaunchStr);

    // İlk açılıştan beri yeterli gün geçti mi?
    if (now.difference(firstLaunch).inDays < _daysBeforeFirstPrompt) return false;

    // Son "hayır" dedikten beri yeterli gün geçti mi?
    final lastDismissedStr = prefs.getString(_lastDismissedKey);
    if (lastDismissedStr != null) {
      final lastDismissed = DateTime.parse(lastDismissedStr);
      if (now.difference(lastDismissed).inDays < _daysAfterDismiss) return false;
    }

    return true;
  }

  /// Kullanıcı "Şimdi Değil" dedi
  static Future<void> dismissReview() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastDismissedKey, DateTime.now().toIso8601String());
  }

  /// Kullanıcı puanladı
  static Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasRatedKey, true);
  }

  /// Yorum pop-up'ını göster
  static Future<void> showReviewDialog(BuildContext context) async {
    if (!await shouldShowReviewPrompt()) return;

    if (!context.mounted) return;

    showDialog(
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
                          onTap: () {
                            markAsRated();
                            Navigator.pop(ctx);
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
