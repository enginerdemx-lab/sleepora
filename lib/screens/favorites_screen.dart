import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../screens/sounds_screen.dart';
import '../widgets/sound_card.dart';
import '../models/shuffle_settings.dart';
import 'paywall_screen.dart';
import '../services/localization_service.dart';
import '../services/subscription_service.dart';

typedef MixerChangedCallback = void Function(List<Sound> selected, VoidCallback? onClear, VoidCallback? onVolume, VoidCallback? onSave);
typedef VolumeChangeCallback = void Function(int index, double volume);
typedef RemoveFromMixCallback = void Function(int index);

class SavedMix {
  final String name;
  final List<Sound> sounds;
  bool isPlaying;
  SavedMix({required this.name, required this.sounds, this.isPlaying = false});
}

class FavoritesScreen extends StatefulWidget {
  final MixerChangedCallback onMixerChanged;
  final void Function(String name, List<Sound> sounds) onSavedMixTapped;
  final void Function(Sound) onSoundTapped;
  final VolumeChangeCallback? onVolumeChange;
  final void Function(String mixName, int soundIndex, double volume)? onMixLiveVolumeChange;
  final RemoveFromMixCallback? onRemoveFromMix;
  // Shuffle özellikleri
  final bool isShufflePlaying;
  final ShuffleSettings shuffleSettings;
  final VoidCallback onShufflePlayPause;
  final ValueChanged<ShuffleSettings> onShuffleSettingsChanged;

  const FavoritesScreen({
    super.key, 
    required this.onMixerChanged, 
    required this.onSavedMixTapped, 
    required this.onSoundTapped,
    this.onVolumeChange,
    this.onMixLiveVolumeChange,
    this.onRemoveFromMix,
    required this.isShufflePlaying,
    required this.shuffleSettings,
    required this.onShufflePlayPause,
    required this.onShuffleSettingsChanged,
  });

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  final _loc = LocalizationService();
  late TabController _tabController;
  int _selectedTab = 0;
  bool get isMixerTab => _selectedTab == 2;
  
  final List<SavedMix> _savedMixes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() => _selectedTab = _tabController.index));
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  /// Dışarıdan karıştırıcı tabına geçmek için
  void goToMixerTab() {
    _tabController.animateTo(2);
  }

  List<Sound> get _favoriteSounds => allSounds.where((s) => s.isFavorite).toList();

  void _addMix(String name, List<Sound> sounds) {
    setState(() {
      _savedMixes.add(SavedMix(name: name, sounds: List.from(sounds)));
    });
    // Kayıt sonrası Mix'lerim tabına git
    _tabController.animateTo(1);
  }

  void _deleteMix(int index) {
    setState(() => _savedMixes.removeAt(index));
  }

  void _editMix(int index, List<Sound> updatedSounds) {
    setState(() {
      _savedMixes[index] = SavedMix(name: _savedMixes[index].name, sounds: List.from(updatedSounds));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(color: const Color(0xFF1A1025), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha:0.06))),
              child: Row(children: [
                _TabItem(label: _loc.t('TabFavorite'), index: 0, selected: _selectedTab, onTap: (i) => _tabController.animateTo(i)),
                _TabItem(label: _loc.t('TabMyMixes'), index: 1, selected: _selectedTab, onTap: (i) => _tabController.animateTo(i)),
                _TabItem(label: _loc.t('TabMixer'), index: 2, selected: _selectedTab, onTap: (i) => _tabController.animateTo(i)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FavoriteSoundsTab(
                  sounds: _favoriteSounds, 
                  onSoundTapped: widget.onSoundTapped,
                  onFavoriteToggle: () => setState(() {}),
                  isShufflePlaying: widget.isShufflePlaying,
                  shuffleSettings: widget.shuffleSettings,
                  onShufflePlayPause: widget.onShufflePlayPause,
                  onShuffleSettingsChanged: widget.onShuffleSettingsChanged,
                ),
                _MixesTab(
                  mixes: _savedMixes,
                  onGoToMixer: () => _tabController.animateTo(2),
                  onDeleteMix: _deleteMix,
                  onEditMix: _editMix,
                  onMixLiveVolumeChange: widget.onMixLiveVolumeChange,
                  onPlayMix: widget.onSavedMixTapped,
                ),
                _MixerTab(
                  currentMixCount: _savedMixes.length,
                  onMixerChanged: widget.onMixerChanged,
                  onSaveMix: _addMix,
                  onVolumeChange: widget.onVolumeChange,
                  onRemoveFromMix: widget.onRemoveFromMix,
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label; final int index; final int selected; final Function(int) onTap;
  const _TabItem({required this.label, required this.index, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: isSelected ? AppColors.purple : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Center(child: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppColors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal))),
        ),
      ),
    );
  }
}

class _FavoriteSoundsTab extends StatelessWidget {
  final List<Sound> sounds;
  final void Function(Sound) onSoundTapped;
  final VoidCallback onFavoriteToggle;
  final bool isShufflePlaying;
  final ShuffleSettings shuffleSettings;
  final VoidCallback onShufflePlayPause;
  final ValueChanged<ShuffleSettings> onShuffleSettingsChanged;

  const _FavoriteSoundsTab({
    required this.sounds, 
    required this.onSoundTapped,
    required this.onFavoriteToggle,
    required this.isShufflePlaying,
    required this.shuffleSettings,
    required this.onShufflePlayPause,
    required this.onShuffleSettingsChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (sounds.isEmpty) {
      final loc = LocalizationService();
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.purple.withValues(alpha:0.2)), child: const Icon(Icons.favorite_border_rounded, color: AppColors.purple, size: 36)),
        const SizedBox(height: 16),
        Text(loc.t('NoFavoritesTitle'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(loc.t('NoFavoritesDesc'), style: TextStyle(color: AppColors.grey, fontSize: 14), textAlign: TextAlign.center),
      ]));
    }
    final loc = LocalizationService();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.purpleDark, AppColors.purple]), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha:0.1))),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha:0.15)), child: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(loc.t('ShuffleFavoritesTitle'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(isShufflePlaying ? loc.t('ShuffleStatusPlaying') : loc.t('ShuffleStatusStopped'), style: TextStyle(color: Colors.white.withValues(alpha:isShufflePlaying ? 0.9 : 0.6), fontSize: 12)),
            ])),
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => _ShuffleSettingsDialog(
                    initialSettings: shuffleSettings,
                    onSave: onShuffleSettingsChanged,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(Icons.tune_rounded, color: Colors.white.withValues(alpha:0.7), size: 22),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onShufflePlayPause,
              child: Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), 
                child: Icon(isShufflePlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.purple, size: 26)),
            ),
          ]),
        ),
      ),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1),
        itemCount: sounds.length,
        itemBuilder: (context, index) {
          final sound = sounds[index];
          return SoundCard(
            sound: sound, 
            onTap: () => onSoundTapped(sound), 
            onFavorite: () {
              sound.isFavorite = !sound.isFavorite;
              onFavoriteToggle();
            },
          );
        },
      )),
    ]);
  }
}

class _MixesTab extends StatelessWidget {
  final List<SavedMix> mixes;
  final VoidCallback onGoToMixer;
  final Function(int) onDeleteMix;
  final void Function(int index, List<Sound> updatedSounds) onEditMix;
  final void Function(String mixName, int index, double volume)? onMixLiveVolumeChange;
  final void Function(String name, List<Sound> sounds) onPlayMix;
  const _MixesTab({required this.mixes, required this.onGoToMixer, required this.onDeleteMix, required this.onEditMix, this.onMixLiveVolumeChange, required this.onPlayMix});

  @override
  Widget build(BuildContext context) {
    final loc = LocalizationService();
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.purple.withValues(alpha:0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.purple.withValues(alpha:0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.music_note_rounded, color: AppColors.purple, size: 18), const SizedBox(width: 8), Text(loc.t('MyMixesHeader'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))])),
      const SizedBox(height: 8),
      Text(loc.t('MyMixesSub'), style: TextStyle(color: AppColors.grey, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      GestureDetector(onTap: onGoToMixer,
        child: Container(width: double.infinity, height: 52, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]), borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add, color: Colors.white, size: 22), const SizedBox(width: 8), Text(loc.t('BtnNewMix'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))]))),
      const SizedBox(height: 16),
      if (mixes.isEmpty) ...[
        const SizedBox(height: 16),
        Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.purple.withValues(alpha:0.2)), child: const Icon(Icons.music_note_rounded, color: AppColors.purple, size: 36)),
        const SizedBox(height: 16),
        Text(loc.t('NoMixesTitle'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(loc.t('NoMixesDesc'), style: TextStyle(color: AppColors.grey, fontSize: 14), textAlign: TextAlign.center),
      ] else Expanded(child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 160),
        itemCount: mixes.length,
        itemBuilder: (context, i) {
          final mix = mixes[i];
          return GestureDetector(
            onTap: () => onPlayMix(mix.name, mix.sounds),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1A1025), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha:0.06))),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.purple.withValues(alpha:0.3)),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(mix.name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${mix.sounds.length} ${loc.t('soundsCount')}', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                ])),
                ...mix.sounds.take(3).map((s) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(s.icon, color: Colors.white.withValues(alpha:0.5), size: 16),
                )),
                if (mix.sounds.length > 3) Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text('+${mix.sounds.length - 3}', style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 11)),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => _EditSavedMixDialog(
                        mixName: mix.name,
                        initialSounds: mix.sounds,
                        onSave: (updatedSounds) => onEditMix(i, updatedSounds),
                        onLiveVolumeChange: (index, vol) => onMixLiveVolumeChange?.call(mix.name, index, vol),
                      ),
                    );
                  },
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.tune_rounded, color: Colors.white70, size: 16),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => onDeleteMix(i),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha:0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                  ),
                ),
              ]),
            ),
          );
        },
      )),
    ]));
  }
}

class _MixerTab extends StatefulWidget {
  final int currentMixCount;
  final MixerChangedCallback onMixerChanged;
  final void Function(String name, List<Sound> sounds) onSaveMix;
  final VolumeChangeCallback? onVolumeChange;
  final RemoveFromMixCallback? onRemoveFromMix;
  const _MixerTab({required this.currentMixCount, required this.onMixerChanged, required this.onSaveMix, this.onVolumeChange, this.onRemoveFromMix});

  @override
  State<_MixerTab> createState() => _MixerTabState();
}

class _MixerTabState extends State<_MixerTab> {
  final _loc = LocalizationService();
  final List<Sound> _selected = [];

  void _toggle(Sound sound) {
    // Premium ses kontrolü — seçili ise çıkarmaya izin ver, eklerken engelle
    if (!_selected.contains(sound) && SubscriptionService().isSoundPremium(sound.name)) {
      _showPremiumSoundDialog();
      return;
    }
    setState(() {
      if (_selected.contains(sound)) _selected.remove(sound);
      else _selected.add(sound);
    });
    _notify();
  }

  void _showPremiumSoundDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1540),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.diamond_rounded, color: Colors.amber, size: 28),
              ),
              const SizedBox(height: 16),
              Text(_loc.t('PremiumSoundTitle'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(_loc.t('PremiumSoundDesc'), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  PaywallScreen.showIfNeeded(context, feature: _loc.t('FeatPremiumSounds'));
                },
                child: Container(
                  width: double.infinity, height: 50,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)]), borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(_loc.t('BtnGoPremium'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity, height: 44,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                  child: Center(child: Text(_loc.t('BtnCancel'), style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _notify() {
    widget.onMixerChanged(
      List.from(_selected),
      () { setState(() => _selected.clear()); _notify(); },
      _showVolumeDialog,
      _showSaveMixDialog,
    );
  }

  void _showVolumeDialog() {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1E1540),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(_loc.t('DialogEdit'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(dialogContext), child: Icon(Icons.close, color: Colors.white.withValues(alpha:0.6))),
            ]),
            const SizedBox(height: 20),
            ...List.generate(_selected.length, (i) => _VolumeItem(
              sound: _selected[i],
              onVolumeChanged: (v) => widget.onVolumeChange?.call(i, v),
              onRemove: () {
                widget.onRemoveFromMix?.call(i);
                setDialogState(() {});
                setState(() {
                  _selected.removeAt(i);
                  _notify();
                });
                if (_selected.isEmpty) Navigator.pop(dialogContext);
              },
            )),
            const SizedBox(height: 16),
            GestureDetector(onTap: () => Navigator.pop(dialogContext),
              child: Container(width: double.infinity, height: 50, decoration: BoxDecoration(color: AppColors.purple, borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(_loc.t('BtnDone'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))))),
          ]));
        },
      ),
    ));
  }

  void _showSaveMixDialog() async {
    if (!mounted || _selected.isEmpty) return;
    
    if (widget.currentMixCount >= 2) {
      bool shouldGoToPaywall = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1540),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('💡 ${_loc.t('MixLimitTitle')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          content: Text(
            _loc.t('MixLimitDesc'), 
            style: const TextStyle(color: Colors.white70)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_loc.t('BtnCancel'), style: TextStyle(color: Colors.white.withValues(alpha:0.5))),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.purple, AppColors.purpleDark]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(_loc.t('BtnSeePlus'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ) ?? false;

      if (shouldGoToPaywall && mounted) {
        await PaywallScreen.showIfNeeded(context, feature: _loc.t('FeatUnlimitedMix'));
      }
      return;
    }
    
    final controller = TextEditingController();
    showDialog(context: context, builder: (_) => Dialog(
      backgroundColor: const Color(0xFF1E1540),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(_loc.t('SaveAsMix'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(onTap: () => Navigator.pop(context), child: Icon(Icons.close, color: Colors.white.withValues(alpha:0.6))),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: _selected.map((s) => Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.purple.withValues(alpha:0.3), borderRadius: BorderRadius.circular(10)), child: Icon(s.icon, color: Colors.white, size: 22))).toList()),
        const SizedBox(height: 16),
        TextField(controller: controller, style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: _loc.t('HintNewMix'), hintStyle: TextStyle(color: Colors.white.withValues(alpha:0.4)), filled: true, fillColor: Colors.white.withValues(alpha:0.1), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            if (controller.text.isNotEmpty) {
              widget.onSaveMix(controller.text, List.from(_selected));
              Navigator.pop(context);
            }
          },
          child: Container(width: double.infinity, height: 50, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.green, AppColors.purple]), borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(_loc.t('BtnSave'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))))),
      ])),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () { setState(() { _selected.clear(); _selected.addAll(allSounds); }); _notify(); },
          child: Container(height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.purpleDark, AppColors.purple]), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(_loc.t('BtnSelectAll'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))))),
        const SizedBox(width: 12),
        Expanded(child: GestureDetector(
          onTap: () { setState(() => _selected.clear()); _notify(); },
          child: Container(height: 44, decoration: BoxDecoration(color: const Color(0xFF1A1025), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha:0.1))),
            child: Center(child: Text(_loc.t('BtnClearAll'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))))),
      ])),
      const SizedBox(height: 12),
      Expanded(child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 160),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1),
        itemCount: allSounds.length,
        itemBuilder: (context, index) {
          final sound = allSounds[index];
          return _MixerCard(sound: sound, isSelected: _selected.contains(sound), onTap: () => _toggle(sound));
        },
      )),
    ]);
  }
}

class _VolumeItem extends StatefulWidget {
  final Sound sound;
  final ValueChanged<double>? onVolumeChanged;
  final VoidCallback? onRemove;
  const _VolumeItem({required this.sound, this.onVolumeChanged, this.onRemove});

  @override
  State<_VolumeItem> createState() => _VolumeItemState();
}

class _VolumeItemState extends State<_VolumeItem> {
  late double _volume;

  @override
  void initState() {
    super.initState();
    _volume = widget.sound.volume;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.07), borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.purple.withValues(alpha:0.4)), child: Icon(widget.sound.icon, color: Colors.white, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.sound.localizedName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500))),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.volume_up_outlined, color: Colors.white.withValues(alpha:0.5), size: 18),
          Expanded(child: SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: AppColors.purple, inactiveTrackColor: Colors.white.withValues(alpha:0.15), thumbColor: Colors.white, trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7), overlayShape: SliderComponentShape.noOverlay),
            child: Slider(value: _volume, onChanged: (v) {
              setState(() => _volume = v);
              widget.onVolumeChanged?.call(v);
            }),
          )),
          Text('${(_volume * 100).toInt()}%', style: TextStyle(color: Colors.white.withValues(alpha:0.6), fontSize: 12)),
        ]),
      ]),
    );
  }
}

class _MixerCard extends StatefulWidget {
  final Sound sound; final bool isSelected; final VoidCallback onTap;
  const _MixerCard({required this.sound, required this.isSelected, required this.onTap});

  @override
  State<_MixerCard> createState() => _MixerCardState();
}

class _MixerCardState extends State<_MixerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _handleTap() { _controller.forward().then((_) => _controller.reverse()); widget.onTap(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (_, __) => Transform.scale(scale: _scaleAnim.value,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              gradient: widget.isSelected
                  ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)])
                  : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1025), Color(0xFF2D1B4E)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.isSelected ? AppColors.purple.withValues(alpha:0.8) : Colors.white.withValues(alpha:0.06), width: widget.isSelected ? 1.5 : 1),
              boxShadow: widget.isSelected ? [BoxShadow(color: AppColors.purple.withValues(alpha:0.4), blurRadius: 14, spreadRadius: 1)] : [],
            ),
            child: Stack(children: [
              if (widget.isSelected) Positioned(top: 6, right: 6, child: Container(width: 18, height: 18, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amber), child: const Icon(Icons.check, color: Colors.white, size: 12))),
              if (SubscriptionService().isSoundPremium(widget.sound.name)) Positioned(top: 6, left: 6, child: Icon(Icons.diamond_rounded, color: Colors.amber.withValues(alpha: 0.8), size: 14)),
              Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.sound.icon, color: SubscriptionService().isSoundPremium(widget.sound.name) ? Colors.white.withValues(alpha: 0.5) : Colors.white, size: 26),
                const SizedBox(height: 6),
                Text(widget.sound.localizedName, style: TextStyle(color: SubscriptionService().isSoundPremium(widget.sound.name) ? Colors.white.withValues(alpha: 0.5) : Colors.white, fontSize: 10), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          )),
      ),
    );
  }
}

// ─── Karışık Çalma Ayarları Dialogu ───
class _ShuffleSettingsDialog extends StatefulWidget {
  final ShuffleSettings initialSettings;
  final ValueChanged<ShuffleSettings> onSave;

  const _ShuffleSettingsDialog({required this.initialSettings, required this.onSave});

  @override
  State<_ShuffleSettingsDialog> createState() => _ShuffleSettingsDialogState();
}

class _ShuffleSettingsDialogState extends State<_ShuffleSettingsDialog> with SingleTickerProviderStateMixin {
  final _loc = LocalizationService();
  late int _changeDuration;
  int? _playbackDuration;
  late bool _crossfadeEnabled;
  late int _crossfadeDuration;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _changeDuration = widget.initialSettings.changeDurationSeconds;
    _playbackDuration = widget.initialSettings.playbackDurationMinutes;
    _crossfadeEnabled = widget.initialSettings.crossfadeEnabled;
    _crossfadeDuration = widget.initialSettings.crossfadeDurationSeconds;

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Widget _buildPlaybackOption(String label, int? value) {
    final isSelected = _playbackDuration == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _playbackDuration = value),
        child: Container(
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.purple : Colors.white.withValues(alpha:0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.6),
              fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            )),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1540),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(_loc.t('ShuffleSettingsTitle'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha:0.1)),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ]),
            const SizedBox(height: 24),

            // Değişim Süresi
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_loc.t('ShuffleChangeInterval'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              Text('$_changeDuration ${_loc.t('sec')}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: _glowController,
              builder: (context, _) => SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.purple, inactiveTrackColor: Colors.white.withValues(alpha:0.15),
                  thumbColor: Colors.white, trackHeight: 6, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                  overlayShape: SliderComponentShape.noOverlay,
                  trackShape: _ShuffleGlowingTrackShape(glowValue: _glowController.value, activeColor: AppColors.purple),
                ),
                child: Slider(
                  value: _changeDuration.toDouble(),
                  min: 5, max: 120, divisions: 115,
                  onChanged: (v) => setState(() => _changeDuration = v.toInt()),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Oynatma Süresi
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_loc.t('ShufflePlayDuration'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              Text(_playbackDuration == null ? _loc.t('ShufflePlayUnlimited') : '$_playbackDuration ${_loc.t('min')}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _buildPlaybackOption('∞', null),
              _buildPlaybackOption('15${_loc.t('min')}', 15),
              _buildPlaybackOption('30${_loc.t('min')}', 30),
              _buildPlaybackOption('60${_loc.t('min')}', 60),
            ]),
            const SizedBox(height: 24),

            // Yumuşak Geçiş (Crossfade)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.05), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Switch(
                  value: _crossfadeEnabled,
                  onChanged: (v) => setState(() => _crossfadeEnabled = v),
                  activeColor: const Color(0xFF10B981),
                  activeTrackColor: const Color(0xFF10B981).withValues(alpha:0.3),
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white.withValues(alpha:0.2),
                ),
                const SizedBox(width: 12),
                Text(_loc.t('ShuffleCrossfade'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
            ),
            
            if (_crossfadeEnabled) ...[
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_loc.t('ShuffleCrossfadeDuration'), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                Text('$_crossfadeDuration ${_loc.t('sec')}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
              const SizedBox(height: 8),
              ListenableBuilder(
                listenable: _glowController,
                builder: (context, _) => SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.purple, inactiveTrackColor: Colors.white.withValues(alpha:0.15),
                    thumbColor: Colors.white, trackHeight: 6, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                    overlayShape: SliderComponentShape.noOverlay,
                    trackShape: _ShuffleGlowingTrackShape(glowValue: _glowController.value, activeColor: AppColors.purple),
                  ),
                  child: Slider(
                    value: _crossfadeDuration.toDouble(),
                    min: 1, max: 10, divisions: 9,
                    onChanged: (v) => setState(() => _crossfadeDuration = v.toInt()),
                  ),
                ),
              ),
            ] else const SizedBox(height: 24),
            
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                // Ensure crossfade duration doesn't exceed change duration
                if (_crossfadeEnabled && _crossfadeDuration >= _changeDuration) {
                  _crossfadeDuration = _changeDuration - 1;
                  if (_crossfadeDuration < 1) _crossfadeDuration = 1;
                }
                
                widget.onSave(ShuffleSettings(
                  changeDurationSeconds: _changeDuration,
                  playbackDurationMinutes: _playbackDuration,
                  crossfadeEnabled: _crossfadeEnabled,
                  crossfadeDurationSeconds: _crossfadeDuration,
                ));
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(color: AppColors.purple, borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(_loc.t('BtnDone'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Kayıtlı Mix Düzenleme (Edit) Dialogu ───
class _EditSavedMixDialog extends StatefulWidget {
  final String mixName;
  final List<Sound> initialSounds;
  final ValueChanged<List<Sound>> onSave;
  final void Function(int index, double volume)? onLiveVolumeChange;

  const _EditSavedMixDialog({required this.mixName, required this.initialSounds, required this.onSave, this.onLiveVolumeChange});

  @override
  State<_EditSavedMixDialog> createState() => _EditSavedMixDialogState();
}

class _EditSavedMixDialogState extends State<_EditSavedMixDialog> {
  final _loc = LocalizationService();
  late List<Sound> _sounds;

  @override
  void initState() {
    super.initState();
    // Kullanıcı vazgeçerse diye yedek kopya üzerinden çalışıyoruz
    _sounds = widget.initialSounds.map((s) => Sound(
      name: s.name, icon: s.icon, assetPath: s.assetPath, isFavorite: s.isFavorite, isPlaying: s.isPlaying, volume: s.volume,
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1540),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('${widget.mixName} ${_loc.t('EditMixTitle')}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha:0.1)),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Text(_loc.t('EditMixDesc'), style: TextStyle(color: AppColors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sounds.length,
                itemBuilder: (context, i) {
                  return _VolumeItem(
                    sound: _sounds[i],
                    onVolumeChanged: (v) {
                      setState(() => _sounds[i].volume = v);
                      widget.onLiveVolumeChange?.call(i, v);
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                widget.onSave(_sounds);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity, height: 50,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(_loc.t('BtnDone'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShuffleGlowingTrackShape extends SliderTrackShape {
  final double glowValue;
  final Color activeColor;

  const _ShuffleGlowingTrackShape({required this.glowValue, required this.activeColor});

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 6;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackLeft = offset.dx + 10;
    final trackWidth = parentBox.size.width - 20;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    final canvas = context.canvas;
    final trackRect = getPreferredRect(parentBox: parentBox, offset: offset, sliderTheme: sliderTheme);
    final radius = Radius.circular(trackRect.height / 2);

    final inactivePaint = Paint()..color = Colors.white.withValues(alpha:0.08);
    canvas.drawRRect(RRect.fromRectAndRadius(trackRect, radius), inactivePaint);

    final activeRect = Rect.fromLTRB(trackRect.left, trackRect.top, thumbCenter.dx, trackRect.bottom);
    if (activeRect.width > 0) {
      final activePaint = Paint()
        ..shader = LinearGradient(
          colors: [activeColor.withValues(alpha:0.8), activeColor],
        ).createShader(activeRect);
      canvas.drawRRect(RRect.fromRectAndRadius(activeRect, radius), activePaint);

      final glowPosition = activeRect.left + (activeRect.width * glowValue);
      final glowWidth = activeRect.width * 0.35;
      final glowRect = Rect.fromCenter(
        center: Offset(glowPosition, activeRect.center.dy),
        width: glowWidth,
        height: activeRect.height,
      ).intersect(activeRect);

      if (glowRect.width > 0) {
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha:0.4),
              Colors.white.withValues(alpha:0.0),
            ],
          ).createShader(Rect.fromCenter(
            center: Offset(glowPosition, activeRect.center.dy),
            width: glowWidth,
            height: activeRect.height * 3,
          ))
          ..blendMode = BlendMode.screen;
        canvas.drawRRect(RRect.fromRectAndRadius(glowRect, radius), glowPaint);
      }

      final outerGlowPaint = Paint()
        ..color = activeColor.withValues(alpha:0.3 + 0.15 * ((glowValue * 2 - 1).abs()))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(activeRect.inflate(2), radius),
        outerGlowPaint,
      );
    }
  }
}

