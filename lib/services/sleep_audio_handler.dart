import 'package:audio_service/audio_service.dart';

/// Kilit ekranı / Kontrol Merkezi Now-Playing entegrasyonu.
/// Gerçek AudioPlayer'lar HomeScreen'de yaşar; bu handler sadece
/// medya meta-datasını yansıtır ve kilit ekranı kontrollerini geri yönlendirir.
class SleepAudioHandler extends BaseAudioHandler {
  // Singleton — HomeScreen'den erişim için
  static SleepAudioHandler? _instance;
  static SleepAudioHandler? get instance => _instance;

  SleepAudioHandler() {
    _instance = this;
  }

  // HomeScreen tarafından her ses değişiminde atanan callback'ler
  void Function()? onPlayPause;
  void Function()? onStop;
  void Function()? onSkipToNext;

  /// Çalan ses değiştiğinde HomeScreen tarafından çağrılır.
  void updateNowPlaying({required String title, required bool isPlaying}) {
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
    ));

    playbackState.add(PlaybackState(
      controls: [
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {MediaAction.stop, MediaAction.skipToNext},
      androidCompactActionIndices: const [0, 1],
      processingState: AudioProcessingState.ready,
      playing: isPlaying,
    ));
  }

  // Kilit ekranı: Oynat düğmesine basıldı
  @override
  Future<void> play() async => onPlayPause?.call();

  // Kilit ekranı: Duraklat düğmesine basıldı
  @override
  Future<void> pause() async => onPlayPause?.call();

  // Kilit ekranı: Durdur düğmesine basıldı
  @override
  Future<void> stop() async {
    onStop?.call();
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
  }

  // Kilit ekranı: Sonraki sese geç
  @override
  Future<void> skipToNext() async => onSkipToNext?.call();
}
