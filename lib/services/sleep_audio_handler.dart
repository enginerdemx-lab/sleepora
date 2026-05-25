import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audio_service/audio_service.dart';

/// Kilit ekranı / Kontrol Merkezi Now-Playing entegrasyonu.
/// Gerçek AudioPlayer'lar HomeScreen'de yaşar; bu handler sadece
/// medya meta-datasını yansıtır ve kilit ekranı kontrollerini geri yönlendirir.
class SleepAudioHandler extends BaseAudioHandler {
  // Singleton — HomeScreen'den erişim için
  static SleepAudioHandler? _instance;
  static SleepAudioHandler? get instance => _instance;

  /// Varsayılan fallback artwork — logo.jpg'den türetilen file:// URI.
  /// Mixer, Shuffle veya artworkPath'i olmayan sesler için kullanılır.
  /// iOS, asset:// URI'larını Now Playing'de desteklemez — temp dosya gerekir.
  static Uri? _defaultArtworkUri;

  /// Ses başına artwork URI'ları. Key: Sound.artworkPath (asset path).
  /// Value: temp klasörüne kopyalanmış file:// URI.
  static final Map<String, Uri> _soundArtworkUris = {};

  SleepAudioHandler() {
    _instance = this;
  }

  /// App başladığında bir kere çağrılır.
  /// Varsayılan logo'yu ve `assetPaths` listesindeki her artwork'ü
  /// temp klasöre kopyalar (iOS'un kabul ettiği file:// URI'ı hazırlar).
  ///
  /// [assetPaths] null ise sadece varsayılan logo hazırlanır.
  static Future<void> initArtwork({List<String>? assetPaths}) async {
    try {
      final dir = await getTemporaryDirectory();

      // Varsayılan logo
      final logoBytes = await rootBundle.load('assets/images/logo.jpg');
      final logoFile = File('${dir.path}/sleepora_artwork.jpg');
      await logoFile.writeAsBytes(logoBytes.buffer.asUint8List());
      _defaultArtworkUri = Uri.file(logoFile.path);
      debugPrint('✅ Varsayılan artwork hazır: $_defaultArtworkUri');

      // Ses başına artwork
      if (assetPaths != null) {
        _soundArtworkUris.clear();
        for (final assetPath in assetPaths) {
          try {
            final bytes = await rootBundle.load(assetPath);
            // Asset path'inden güvenli bir dosya adı üret
            final safeName = assetPath
                .replaceAll('/', '_')
                .replaceAll(' ', '_');
            final file = File('${dir.path}/$safeName');
            await file.writeAsBytes(bytes.buffer.asUint8List());
            _soundArtworkUris[assetPath] = Uri.file(file.path);
          } catch (e) {
            debugPrint('⚠️ Artwork yüklenemedi: $assetPath — $e');
          }
        }
        debugPrint('✅ ${_soundArtworkUris.length} ses artwork hazırlandı');
      }
    } catch (e) {
      debugPrint('⚠️ Artwork init hatası: $e');
    }
  }

  /// Verilen asset path için hazırlanmış file:// URI'yı döner.
  /// Bulunamazsa varsayılan logoyu döner.
  static Uri? artworkFor(String? assetPath) {
    if (assetPath == null) return _defaultArtworkUri;
    return _soundArtworkUris[assetPath] ?? _defaultArtworkUri;
  }

  // HomeScreen tarafından her ses değişiminde atanan callback'ler.
  //
  // ÖNEMLİ: Tüm callback'ler `Future<void>` döner — handler tarafı await edip
  // bittiğinden emin olur. void Function ile bırakılırsa, callback async yol
  // izlediğinde audio_service tamamlandı sayar; bekçi (watchdog) veya
  // interruption.end işleyici hatalı state ile devam edebilir.
  Future<void> Function()? onPlay;   // Kilit ekranı: sadece oynat
  Future<void> Function()? onPause;  // Kilit ekranı: sadece duraklat
  Future<void> Function()? onStop;
  Future<void> Function()? onSkipToNext;
  Future<void> Function()? onSkipToPrevious;

  /// AdService tarafından reklam kapandıktan sonra çağrılır.
  /// just_audio'nun iOS AVPlayer'ı reklam sonrası audio route'u kaybediyor;
  /// sadece play() yetmiyor → bu callback `stop + setAsset + play` yapan
  /// "hard reload" yolunu tetikler. Artık mixer/shuffle modlarında da set
  /// edilir (her birinin kendi hard-reload Future'ı var).
  Future<void> Function()? onResumeAfterAd;

  /// Çalan ses değiştiğinde HomeScreen tarafından çağrılır.
  ///
  /// [artworkAssetPath] belirtilirse o sesin resmi gösterilir,
  /// yoksa varsayılan logo kullanılır.
  void updateNowPlaying({
    required String title,
    required bool isPlaying,
    String? artworkAssetPath,
  }) {
    if (title.isEmpty) {
      mediaItem.add(null);
      playbackState.add(PlaybackState(
        processingState: AudioProcessingState.idle,
        playing: false,
      ));
      return;
    }

    mediaItem.add(MediaItem(
      id: 'sleepora_now_playing',
      title: title,
      artist: 'Sleepora',
      displayTitle: title,
      displaySubtitle: 'Sleepora',
      duration: const Duration(hours: 8), // Required by some iOS versions to show player
      artUri: artworkFor(artworkAssetPath), // Ses başına veya varsayılan
    ));

    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.stop, MediaAction.skipToNext, MediaAction.skipToPrevious},
      androidCompactActionIndices: const [0, 1],
      processingState: AudioProcessingState.ready,
      playing: isPlaying,
    ));
  }

  // Kilit ekranı: Oynat düğmesine basıldı
  @override
  Future<void> play() async {
    final cb = onPlay;
    if (cb != null) await cb();
  }

  // Kilit ekranı: Duraklat düğmesine basıldı
  @override
  Future<void> pause() async {
    final cb = onPause;
    if (cb != null) await cb();
  }

  // Kilit ekranı: Durdur düğmesine basıldı
  @override
  Future<void> stop() async {
    final cb = onStop;
    if (cb != null) await cb();
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  // Kilit ekranı: Sonraki sese geç
  @override
  Future<void> skipToNext() async {
    final cb = onSkipToNext;
    if (cb != null) await cb();
  }

  // Kilit ekranı: Önceki sese dön
  @override
  Future<void> skipToPrevious() async {
    final cb = onSkipToPrevious;
    if (cb != null) await cb();
  }
}
