import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/features/player/player_settings_local_state.dart';

void main() {
  group('PlayerSettingsLocalState', () {
    test('defaults are off', () {
      const s = PlayerSettingsLocalState();
      expect(s.stableVolume, isFalse);
      expect(s.voiceBoost, isFalse);
      expect(s.ambientMode, isFalse);
      expect(s.sleepTimerMinutes, isNull);
    });

    test('toggles flip independent flags', () {
      var s = const PlayerSettingsLocalState();
      s = s.toggleStableVolume();
      expect(s.stableVolume, isTrue);
      expect(s.voiceBoost, isFalse);
      s = s.toggleVoiceBoost().toggleAmbientMode();
      expect(s.voiceBoost, isTrue);
      expect(s.ambientMode, isTrue);
      s = s.toggleStableVolume();
      expect(s.stableVolume, isFalse);
    });

    test('sleep timer accepts known minutes and end-of-video', () {
      var s = const PlayerSettingsLocalState();
      s = s.withSleepTimer(15);
      expect(s.sleepTimerMinutes, 15);
      s = s.withSleepTimer(30);
      expect(s.sleepTimerMinutes, 30);
      s = s.withSleepTimer(PlayerSettingsLocalState.sleepTimerEndOfVideo);
      expect(
        s.sleepTimerMinutes,
        PlayerSettingsLocalState.sleepTimerEndOfVideo,
      );
      s = s.withSleepTimer(null);
      expect(s.sleepTimerMinutes, isNull);
      s = s.withSleepTimer(99);
      expect(s.sleepTimerMinutes, isNull);
    });

    test('equality tracks fields', () {
      const a = PlayerSettingsLocalState(stableVolume: true);
      const b = PlayerSettingsLocalState(stableVolume: true);
      const c = PlayerSettingsLocalState(voiceBoost: true);
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('playerSleepTimerValueLabel', () {
    test('formats minutes, off, and end of video', () {
      expect(playerSleepTimerValueLabel(null, 'Off'), 'Off');
      expect(playerSleepTimerValueLabel(15, 'Off'), '15m');
      expect(playerSleepTimerValueLabel(60, 'Off'), '60m');
      expect(
        playerSleepTimerValueLabel(
          PlayerSettingsLocalState.sleepTimerEndOfVideo,
          'Off',
          endOfVideoLabel: 'End of video',
        ),
        'End of video',
      );
    });
  });
}
