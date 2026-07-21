import 'package:flutter/foundation.dart';

/// Local-only player settings stubs (DESIGN.md §8).
///
/// Does **not** change media output — UI state for the settings overlay only.
@immutable
class PlayerSettingsLocalState {
  const PlayerSettingsLocalState({
    this.stableVolume = false,
    this.voiceBoost = false,
    this.ambientMode = false,
    this.sleepTimerMinutes,
  });

  final bool stableVolume;
  final bool voiceBoost;
  final bool ambientMode;

  /// `null` = off.
  /// [sleepTimerEndOfVideo] = pause when the current media completes.
  /// Otherwise minutes from [sleepTimerOptions] (15 / 30 / 60).
  final int? sleepTimerMinutes;

  /// Sentinel: sleep until the current video ends (not a minute count).
  static const int sleepTimerEndOfVideo = 0;

  static const List<int> sleepTimerOptions = [15, 30, 60];

  PlayerSettingsLocalState copyWith({
    bool? stableVolume,
    bool? voiceBoost,
    bool? ambientMode,
    int? sleepTimerMinutes,
    bool clearSleepTimer = false,
  }) {
    return PlayerSettingsLocalState(
      stableVolume: stableVolume ?? this.stableVolume,
      voiceBoost: voiceBoost ?? this.voiceBoost,
      ambientMode: ambientMode ?? this.ambientMode,
      sleepTimerMinutes: clearSleepTimer
          ? null
          : (sleepTimerMinutes ?? this.sleepTimerMinutes),
    );
  }

  PlayerSettingsLocalState toggleStableVolume() =>
      copyWith(stableVolume: !stableVolume);

  PlayerSettingsLocalState toggleVoiceBoost() =>
      copyWith(voiceBoost: !voiceBoost);

  PlayerSettingsLocalState toggleAmbientMode() =>
      copyWith(ambientMode: !ambientMode);

  PlayerSettingsLocalState withSleepTimer(int? minutes) {
    if (minutes == null) return copyWith(clearSleepTimer: true);
    if (minutes == sleepTimerEndOfVideo) {
      return copyWith(sleepTimerMinutes: sleepTimerEndOfVideo);
    }
    if (!sleepTimerOptions.contains(minutes)) {
      return copyWith(clearSleepTimer: true);
    }
    return copyWith(sleepTimerMinutes: minutes);
  }

  @override
  bool operator ==(Object other) {
    return other is PlayerSettingsLocalState &&
        other.stableVolume == stableVolume &&
        other.voiceBoost == voiceBoost &&
        other.ambientMode == ambientMode &&
        other.sleepTimerMinutes == sleepTimerMinutes;
  }

  @override
  int get hashCode => Object.hash(
        stableVolume,
        voiceBoost,
        ambientMode,
        sleepTimerMinutes,
      );
}

/// Display label for sleep timer (`null` → [offLabel]).
String playerSleepTimerValueLabel(
  int? minutes,
  String offLabel, {
  String? endOfVideoLabel,
}) {
  if (minutes == null) return offLabel;
  if (minutes == PlayerSettingsLocalState.sleepTimerEndOfVideo) {
    return endOfVideoLabel ?? offLabel;
  }
  return '${minutes}m';
}
