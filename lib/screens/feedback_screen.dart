import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/feedback_service.dart';
import '../services/localization_service.dart';

/// Sleepora Geri Bildirim Ekranı
///
/// Kullanıcıların uygulama hakkında geri bildirim gönderebildiği,
/// Sleepora'nın koyu mor temasıyla tasarlanmış şık bir form.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();

  /// Bottom sheet olarak aç
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FeedbackScreen(),
    );
  }
}

class _FeedbackScreenState extends State<FeedbackScreen>
    with TickerProviderStateMixin {
  final _auth = AuthService();
  final _loc = LocalizationService();
  final _messageController = TextEditingController();

  FeedbackCategory _selectedCategory = FeedbackCategory.general;
  bool _isSending = false;
  bool _success = false;
  String? _error;

  late AnimationController _successAnim;
  late AnimationController _shakeAnim;
  late Animation<double> _shakeOffset;

  @override
  void initState() {
    super.initState();
    _successAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shakeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeOffset = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeAnim, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _successAnim.dispose();
    _shakeAnim.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final msg = _messageController.text.trim();
    if (msg.length < 10) {
      setState(() => _error = _loc.t('FeedbackMinChars'));
      _shakeAnim.forward(from: 0);
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    final success = await FeedbackService().sendFeedback(
      category: _selectedCategory,
      message: msg,
      uid: _auth.uid,
      email: _auth.email,
      displayName: _auth.displayName,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isSending = false;
        _success = true;
      });
      _successAnim.forward();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _isSending = false;
        _error = _loc.t('FeedbackSendError');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final pad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D0820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + (pad > 0 ? pad : 20)),
      child: _success ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: CurvedAnimation(
              parent: _successAnim,
              curve: Curves.elasticOut,
            ),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5DE8DA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  color: Colors.white, size: 38),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _loc.t('FeedbackThanks'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _loc.t('FeedbackSuccess'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Handle ───
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),

        // ─── Başlık ───
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.rate_review_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _loc.t('FeedbackTitle'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _loc.t('FeedbackSubtitle'),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── Kategori ───
        Text(
          _loc.t('FeedbackCategoryLabel'),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: FeedbackCategory.values.map((cat) {
            final selected = _selectedCategory == cat;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: cat != FeedbackCategory.general ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF7C3AED)
                          : Colors.white12,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(cat.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(
                        cat.label.split(' ').last,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // ─── Mesaj ───
        Text(
          _loc.t('FeedbackMessageLabel'),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),

        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (context, child) {
            final offset = sin(_shakeAnim.value * pi * 5) * _shakeOffset.value;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _error != null
                    ? Colors.redAccent.withValues(alpha: 0.6)
                    : Colors.white12,
              ),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 5,
              maxLength: 500,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _loc.t('FeedbackMessageHint'),
                hintStyle:
                    const TextStyle(color: Colors.white30, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: const TextStyle(color: Colors.white24),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.redAccent, size: 14),
              const SizedBox(width: 6),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),

        // ─── Gönder butonu ───
        SizedBox(
          width: double.infinity,
          height: 52,
          child: GestureDetector(
            onTap: _isSending ? null : _send,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                gradient: _isSending
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF9D5FF3)],
                      ),
                color: _isSending ? Colors.white12 : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isSending
                    ? null
                    : [
                        BoxShadow(
                          color:
                              const Color(0xFF7C3AED).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _loc.t('FeedbackSendBtn'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ─── Anonim notu ───
        Center(
          child: Text(
            _auth.isLoggedIn
                ? '${_auth.displayName ?? _auth.email ?? _loc.t('FeedbackYou')} ${_loc.t('FeedbackSendingAs')}'
                : _loc.t('FeedbackAnonymous'),
            style:
                const TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ),
      ],
    );
  }
}
