class ShuffleSettings {
  int changeDurationSeconds;
  int? playbackDurationMinutes; // null = Süresiz
  bool crossfadeEnabled;
  int crossfadeDurationSeconds;

  ShuffleSettings({
    this.changeDurationSeconds = 30,
    this.playbackDurationMinutes,
    this.crossfadeEnabled = true,
    this.crossfadeDurationSeconds = 3,
  });

  ShuffleSettings copyWith({
    int? changeDurationSeconds,
    int? playbackDurationMinutes,
    bool? crossfadeEnabled,
    int? crossfadeDurationSeconds,
  }) {
    // If playbackDurationMinutes is passed as exactly -1, we map it back to null
    // But since Dart supports nullable types, we can use a wrapper or just check
    return ShuffleSettings(
      changeDurationSeconds: changeDurationSeconds ?? this.changeDurationSeconds,
      playbackDurationMinutes: playbackDurationMinutes, // We'll handle this explicitly when calling
      crossfadeEnabled: crossfadeEnabled ?? this.crossfadeEnabled,
      crossfadeDurationSeconds: crossfadeDurationSeconds ?? this.crossfadeDurationSeconds,
    );
  }
}
