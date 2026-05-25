/// Sleepora Küfür / Argo Filtresi
///
/// Türkçe ve İngilizce yaygın küfür/argo kelimeleri tespit eder.
/// Harf-rakam değiştirme (leet speak), boşluk ekleme gibi
/// hilelere karşı normalleştirme uygular.
///
/// Kullanım:
///   if (ProfanityFilter.containsProfanity('test')) { ... }
///   final clean = ProfanityFilter.censor('kötü kelime');
class ProfanityFilter {
  ProfanityFilter._();

  // ─── Türkçe küfür/argo listesi ───
  static const List<String> _turkishWords = [
    'amk', 'aq', 'amq', 'amcık', 'amcik', 'amına', 'amina',
    'ananı', 'anani', 'ananızı', 'ananizi', 'anasını', 'anasini',
    'orospu', 'oruspu', 'orospuçocuğu', 'orospucocugu',
    'piç', 'pic', 'piçlik', 'piclik',
    'sik', 'sikim', 'sikik', 'sikerim', 'sikeyim', 'siktir',
    'siktir', 'siktirin', 'siktirgit',
    'göt', 'got', 'götüne', 'gotune', 'götveren', 'gotveren',
    'yarak', 'yarrak', 'yarrağ', 'yarrag',
    'taşak', 'tassak', 'taşşak',
    'meme', // bağlama göre — çift kontrol
    'pezevenk', 'puşt', 'pust', 'ibne', 'gavat', 'gerizekalı',
    'gerizekali', 'aptal', 'salak', 'mal', 'dangalak', 'hıyar',
    'hiyar', 'döl', 'dol', 'kaltak', 'fahişe', 'fahise',
    'kahpe', 'kevaşe', 'kevase', 'şerefsiz', 'serefsiz',
    'bok', 'boktan', 'haysiyetsiz', 'namussuz',
    'ananıskim', 'ananiskim', 'ananısikeyim', 'anansikeyim',
    'hassiktir', 'hassktir', 'hasiktir',
    'yarramı', 'yarrami', 'dalyarak', 'dallama',
    'oç', 'oc', 'mk', 'mq', 'ananıavradını',
    'am', 'amcıq', 'amciq',
    'sokam', 'sokarım', 'sokarim', 'soxam',
    'yavşak', 'yavsak', 'çük', 'cuk', 'zıkkım', 'zikkim',
    'züppə', 'kodumun', 'kodoğlu', 'kodoglu',
  ];

  // ─── İngilizce küfür/argo listesi ───
  static const List<String> _englishWords = [
    'fuck', 'fucker', 'fucking', 'fck', 'fuk', 'f*ck',
    'shit', 'shitty', 'bullshit', 'sh1t',
    'ass', 'asshole', 'a\$\$', 'a\$\$hole',
    'bitch', 'b1tch', 'biatch',
    'dick', 'd1ck', 'dickhead',
    'cock', 'c0ck', 'cocksucker',
    'pussy', 'pu\$\$y',
    'cunt', 'c*nt',
    'bastard', 'b@stard',
    'damn', 'dammit',
    'whore', 'wh0re', 'slut', 'sl*t',
    'nigger', 'n1gger', 'nigga', 'n1gga',
    'retard', 'retarded',
    'faggot', 'fag', 'f@g',
    'motherfucker', 'mf', 'stfu', 'wtf',
    'penis', 'vagina',
    'boob', 'boobs',
    'porn', 'porno', 'p0rn',
    'sex', 'sexy',
    'dildo', 'jerk', 'wanker',
    'twat', 'piss', 'prick',
    'nazi', 'hitler',
  ];

  /// Tüm yasaklı kelimeleri tek bir Set'te birleştir (hız için).
  static final Set<String> _allWords = {
    ..._turkishWords.map((w) => _normalize(w)),
    ..._englishWords.map((w) => _normalize(w)),
  };

  /// Metni normalleştir: küçük harfe çevir, leet speak dönüştür,
  /// boşluk/özel karakter temizle.
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('@', 'a')
        .replaceAll('4', 'a')
        .replaceAll('\$', 's')
        .replaceAll('5', 's')
        .replaceAll('1', 'i')
        .replaceAll('!', 'i')
        .replaceAll('0', 'o')
        .replaceAll('3', 'e')
        .replaceAll('7', 't')
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('ş', 's')
        .replaceAll(RegExp(r'[^a-z0-9]'), ''); // Özel karakter temizle
  }

  /// Verilen metinde küfür/argo olup olmadığını kontrol eder.
  ///
  /// Hem tam kelime eşleşmesi hem de alt-dize (substring) taraması yapar.
  /// Böylece "xyzamkxyz" gibi gizleme denemeleri de yakalanır.
  static bool containsProfanity(String text) {
    if (text.trim().isEmpty) return false;

    final normalized = _normalize(text);

    // 1. Tam kelime eşleşme (boşlukla ayrılmış her kelime)
    final words = normalized.split(RegExp(r'\s+'));
    for (final word in words) {
      if (_allWords.contains(word)) return true;
    }

    // 2. Substring taraması — bütün metinde gizlenmiş küfür arama
    for (final banned in _allWords) {
      if (banned.length >= 3 && normalized.contains(banned)) {
        return true;
      }
    }

    return false;
  }

  /// Küfürlü kelimeleri yıldızla (*) sansürler.
  /// UI'da gösterilmesi gereken durumlarda kullanılabilir.
  static String censor(String text) {
    if (text.trim().isEmpty) return text;

    String result = text;
    final lowerText = _normalize(text);

    for (final banned in _allWords) {
      if (banned.length >= 3 && lowerText.contains(banned)) {
        // Orijinal metindeki eşleşen kısmı bul ve yıldızla değiştir
        final pattern = RegExp(banned, caseSensitive: false);
        result = result.replaceAll(pattern, '*' * banned.length);
      }
    }

    return result;
  }
}
