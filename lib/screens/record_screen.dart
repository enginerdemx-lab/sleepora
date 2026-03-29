import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import '../services/localization_service.dart';

// ─── Native recorder via MethodChannel ───
class NativeRecorder {
  static const _channel = MethodChannel('com.sleepora/recorder');

  static Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startRecording(String path) async {
    try {
      final result = await _channel.invokeMethod<bool>('startRecording', {'path': path});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> pauseRecording() async {
    try {
      final result = await _channel.invokeMethod<bool>('pauseRecording');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> resumeRecording() async {
    try {
      final result = await _channel.invokeMethod<bool>('resumeRecording');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> stopRecording() async {
    try {
      final result = await _channel.invokeMethod<String>('stopRecording');
      return result;
    } catch (_) {
      return null;
    }
  }
}

// ─── Recording Model ───
class Recording {
  String name;
  final String path;
  final DateTime date;
  final Duration duration;

  Recording({
    required this.name,
    required this.path,
    required this.date,
    required this.duration,
  });

  String get formattedDate =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String get formattedDuration {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String toStorageString() =>
      '$name|$path|${date.millisecondsSinceEpoch}|${duration.inSeconds}';

  static Recording? fromStorageString(String s) {
    final parts = s.split('|');
    if (parts.length < 4) return null;
    return Recording(
      name: parts[0],
      path: parts[1],
      date: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[2])),
      duration: Duration(seconds: int.parse(parts[3])),
    );
  }
}

// ─── Record Screen ───
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with TickerProviderStateMixin {
  final _loc = LocalizationService();
  final AudioPlayer _playbackPlayer = AudioPlayer();

  // Recording state
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _currentRecordingPath;

  // Waveform
  List<double> _waveformLevels = List.filled(30, 0.2);
  Timer? _waveformTimer;

  // Playback
  int? _playingIndex;
  bool _isPlaying = false;

  // Recordings
  List<Recording> _recordings = [];

  // Pulse animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadRecordings();
    _playbackPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _playingIndex = null;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _waveformTimer?.cancel();
    _pulseController.dispose();
    _playbackPlayer.dispose();
    super.dispose();
  }

  // ─── Persistence ───
  Future<void> _loadRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('recordings') ?? [];
    final loaded = <Recording>[];
    for (final s in list) {
      final r = Recording.fromStorageString(s);
      if (r != null && File(r.path).existsSync()) {
        loaded.add(r);
      }
    }
    if (mounted) setState(() => _recordings = loaded);
  }

  Future<void> _saveRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'recordings',
      _recordings.map((r) => r.toStorageString()).toList(),
    );
  }

  // ─── Recording ───
  Future<void> _startRecording() async {
    // Premium kontrolü — 1'den fazla kayıt için premium gerekli
    if (SubscriptionService().isRecordingLimitReached(_recordings.length)) {
      await PaywallScreen.showIfNeeded(context, feature: _loc.t('FeatUnlimitedRecord'));
      return;
    }
    try {
      final hasPermission = await NativeRecorder.hasPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_loc.t('MicPermissionRequired')),
              backgroundColor: AppColors.red,
            ),
          );
        }
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      _currentRecordingPath =
          '${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

      final started = await NativeRecorder.startRecording(_currentRecordingPath!);
      if (!started) return;

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordDuration = Duration.zero;
      });
      _pulseController.repeat(reverse: true);
      _startTimer();
      _startWaveform();
    } catch (e) {
      debugPrint('Recording error: $e');
    }
  }

  Future<void> _pauseRecording() async {
    await NativeRecorder.pauseRecording();
    _pulseController.stop();
    _waveformTimer?.cancel();
    setState(() => _isPaused = true);
  }

  Future<void> _resumeRecording() async {
    await NativeRecorder.resumeRecording();
    _pulseController.repeat(reverse: true);
    _startWaveform();
    setState(() => _isPaused = false);
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    _waveformTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    await NativeRecorder.stopRecording();

    if (_currentRecordingPath != null &&
        File(_currentRecordingPath!).existsSync()) {
      final recording = Recording(
        name: '${_loc.t('DefaultRecordName')} ${_recordings.length + 1}',
        path: _currentRecordingPath!,
        date: DateTime.now(),
        duration: _recordDuration,
      );
      setState(() {
        _recordings.insert(0, recording);
      });
      _saveRecordings();
    }
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordDuration = Duration.zero;
      _waveformLevels = List.filled(30, 0.2);
      _currentRecordingPath = null;
    });
  }

  Future<void> _deleteCurrentRecording() async {
    _recordTimer?.cancel();
    _waveformTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    await NativeRecorder.stopRecording();
    if (_currentRecordingPath != null) {
      try {
        File(_currentRecordingPath!).deleteSync();
      } catch (_) {}
    }
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordDuration = Duration.zero;
      _waveformLevels = List.filled(30, 0.2);
      _currentRecordingPath = null;
    });
  }

  void _startTimer() {
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isPaused && mounted) {
        setState(() => _recordDuration += const Duration(seconds: 1));
      }
    });
  }

  void _startWaveform() {
    _waveformTimer?.cancel();
    final rng = Random();
    _waveformTimer =
        Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (_isRecording && !_isPaused && mounted) {
        setState(() {
          _waveformLevels =
              List.generate(30, (i) => 0.15 + rng.nextDouble() * 0.85);
        });
      }
    });
  }

  // ─── Playback ───
  Future<void> _playRecording(int index) async {
    if (_playingIndex == index && _isPlaying) {
      await _playbackPlayer.pause();
      setState(() => _isPlaying = false);
      return;
    }
    try {
      await _playbackPlayer.setFilePath(_recordings[index].path);
      await _playbackPlayer.play();
      setState(() {
        _playingIndex = index;
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  // ─── Edit / Delete ───
  void _renameRecording(int index) {
    final controller = TextEditingController(text: _recordings[index].name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_loc.t('RenameRecordTitle'),
            style: const TextStyle(color: AppColors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.cardDark,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            hintText: _loc.t('HintNewName'),
            hintStyle: const TextStyle(color: AppColors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_loc.t('BtnCancel'), style: const TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() => _recordings[index].name = controller.text.trim());
                _saveRecordings();
              }
              Navigator.pop(ctx);
            },
            child: Text(_loc.t('BtnSave'), style: const TextStyle(color: AppColors.purple)),
          ),
        ],
      ),
    );
  }

  void _deleteRecording(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_loc.t('DeleteRecordTitle'),
            style: const TextStyle(color: AppColors.white, fontSize: 16)),
        content: Text(
          '"${_recordings[index].name}" ${_loc.t('DeleteRecordConfirm')}',
          style: const TextStyle(color: AppColors.greyLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_loc.t('BtnCancel'), style: const TextStyle(color: AppColors.grey)),
          ),
          TextButton(
            onPressed: () {
              final rec = _recordings[index];
              try { File(rec.path).deleteSync(); } catch (_) {}
              if (_playingIndex == index) {
                _playbackPlayer.stop();
                _playingIndex = null;
                _isPlaying = false;
              }
              setState(() => _recordings.removeAt(index));
              _saveRecordings();
              Navigator.pop(ctx);
            },
            child: Text(_loc.t('BtnDelete'), style: const TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  String get _timerText {
    final m = _recordDuration.inMinutes;
    final s = _recordDuration.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')} : ${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(width: 36),
                  const Spacer(),
                  Text(
                    _loc.t('TabRecord'),
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
            ),

            // ─── Subtitle ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _loc.t('RecordSub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.greyLight.withValues(alpha:0.7),
                    fontSize: 13,
                    height: 1.4),
              ),
            ),

            const SizedBox(height: 28),

            // ─── Timer ───
            Text(
              _timerText,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 64,
                fontWeight: FontWeight.w300,
                letterSpacing: 8,
              ),
            ),

            const SizedBox(height: 24),

            // ─── Waveform ───
            SizedBox(
              height: 30,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(30, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 6,
                    height: 6 + (_waveformLevels[i] * 20),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _isRecording
                          ? AppColors.purple.withValues(alpha:0.5 + _waveformLevels[i] * 0.5)
                          : AppColors.grey.withValues(alpha:0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

            const Spacer(),

            // ─── Control Buttons ───
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Delete
                GestureDetector(
                  onTap: _isRecording ? _deleteCurrentRecording : null,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isRecording ? AppColors.card : AppColors.card.withValues(alpha:0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: _isRecording ? AppColors.greyLight : AppColors.grey.withValues(alpha:0.4),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 28),

                // Record / Stop
                GestureDetector(
                  onTap: () {
                    if (!_isRecording) {
                      _startRecording();
                    } else {
                      _stopRecording();
                    }
                  },
                  child: ScaleTransition(
                    scale: _isRecording
                        ? _pulseAnimation
                        : const AlwaysStoppedAnimation(1.0),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: _isRecording
                              ? [AppColors.red, AppColors.red.withValues(alpha:0.7)]
                              : [AppColors.purple, AppColors.purpleLight],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording ? AppColors.red : AppColors.purple)
                                .withValues(alpha:0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        color: AppColors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 28),

                // Pause / Resume
                GestureDetector(
                  onTap: () {
                    if (!_isRecording) return;
                    if (_isPaused) {
                      _resumeRecording();
                    } else {
                      _pauseRecording();
                    }
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isRecording ? AppColors.card : AppColors.card.withValues(alpha:0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      color: _isRecording ? AppColors.greyLight : AppColors.grey.withValues(alpha:0.4),
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ─── Status Text ───
            Text(
              _isRecording
                  ? (_isPaused ? _loc.t('StatusPaused') : _loc.t('StatusRecording'))
                  : _loc.t('StatusStartRecord'),
              style: TextStyle(
                color: _isRecording
                    ? (_isPaused ? AppColors.greyLight : AppColors.red)
                    : AppColors.purple,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),

            const SizedBox(height: 20),

            // ─── Recordings List ───
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha:0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _loc.t('MyRecords'),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_recordings.isNotEmpty)
                            Text(
                              _loc.t('BtnEditCaps'),
                              style: const TextStyle(
                                color: AppColors.purple,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _recordings.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mic_none_rounded,
                                      color: AppColors.grey.withValues(alpha:0.3), size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    _loc.t('NoRecords'),
                                    style: TextStyle(
                                        color: AppColors.grey.withValues(alpha:0.5), fontSize: 14),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: _recordings.length,
                              itemBuilder: (context, index) {
                                return _RecordingItem(
                                  recording: _recordings[index],
                                  isPlaying: _playingIndex == index && _isPlaying,
                                  onPlay: () => _playRecording(index),
                                  onRename: () => _renameRecording(index),
                                  onDelete: () => _deleteRecording(index),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recording List Item ───
class _RecordingItem extends StatelessWidget {
  final Recording recording;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _RecordingItem({
    required this.recording,
    required this.isPlaying,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardDark.withValues(alpha:0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onPlay,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isPlaying ? AppColors.purple.withValues(alpha:0.2) : AppColors.card,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isPlaying ? AppColors.purple : AppColors.greyLight,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording.name,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${recording.formattedDate}  •  ${recording.formattedDuration}',
                  style: const TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRename,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.edit_outlined, color: AppColors.greyLight, size: 18),
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.delete_outline_rounded, color: AppColors.greyLight, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
