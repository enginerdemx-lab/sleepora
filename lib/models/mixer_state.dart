import '../screens/sounds_screen.dart';

class MixerState {
  final List<Sound> selected;
  final void Function() onClear;
  final void Function() onVolume;
  final void Function() onSave;

  MixerState({
    required this.selected,
    required this.onClear,
    required this.onVolume,
    required this.onSave,
  });
}
