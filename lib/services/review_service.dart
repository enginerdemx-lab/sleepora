import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1A1025),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u{2B50}', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'Sleepora\'yı Beğendiniz mi?',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Uygulamayı puanlayarak diğer ailelere yardımcı olabilirsiniz.',
                style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Puanla butonu
              GestureDetector(
                onTap: () {
                  markAsRated();
                  Navigator.pop(ctx);
                  // TODO: App Store'a yönlendir
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('Uygulamayı Puanla', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Şimdi değil butonu
              GestureDetector(
                onTap: () {
                  dismissReview();
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha:0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text('Şimdi Değil', style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
