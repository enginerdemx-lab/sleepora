import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'localization_service.dart';

/// Sleepora Geri Bildirim Servisi
///
/// Kullanıcıların uygulama içinden gönderdikleri geri bildirimleri
/// Firestore `feedbacks` koleksiyonuna kaydeder.
///
/// Koleksiyon yapısı:
///   feedbacks/{id}  → uid, email, display_name, category, message,
///                     platform, created_at, is_read, is_resolved
///
/// Kullanım:
///   await FeedbackService().sendFeedback(
///     category: FeedbackCategory.suggestion,
///     message: 'Harika bir uygulama!',
///   );
class FeedbackService {
  // ─── Singleton ───
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _feedbacksRef =>
      _db.collection('feedbacks');

  /// Geri bildirim gönderir.
  ///
  /// [uid] ve [email] opsiyonel — anonim kullanıcılar da gönderebilir.
  Future<bool> sendFeedback({
    required FeedbackCategory category,
    required String message,
    String? uid,
    String? email,
    String? displayName,
  }) async {
    if (message.trim().length < 10) return false;

    try {
      await _feedbacksRef.add({
        'uid': uid,
        'email': email,
        'display_name': displayName,
        'category': category.value,
        'message': message.trim(),
        'platform': 'ios',
        'app_version': '1.0.0',
        'created_at': FieldValue.serverTimestamp(),
        'is_read': false,
        'is_resolved': false,
      });
      debugPrint('💬 Geri bildirim gönderildi: ${category.value}');
      return true;
    } catch (e) {
      debugPrint('❌ FeedbackService sendFeedback hatası: $e');
      return false;
    }
  }
}

/// Geri bildirim kategorisi
enum FeedbackCategory {
  bug('bug'),
  suggestion('suggestion'),
  general('general');

  const FeedbackCategory(this.value);
  final String value;

  String get label {
    final loc = LocalizationService();
    switch (this) {
      case FeedbackCategory.bug:
        return '🐛 ${loc.t('FeedbackCatBug')}';
      case FeedbackCategory.suggestion:
        return '💡 ${loc.t('FeedbackCatSuggestion')}';
      case FeedbackCategory.general:
        return '💬 ${loc.t('FeedbackCatGeneral')}';
    }
  }

  String get emoji {
    switch (this) {
      case FeedbackCategory.bug:
        return '🐛';
      case FeedbackCategory.suggestion:
        return '💡';
      case FeedbackCategory.general:
        return '💬';
    }
  }
}
