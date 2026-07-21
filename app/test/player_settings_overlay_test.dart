import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextpili/bridge/core_api.dart';
import 'package:nextpili/core/theme/player_colors.dart';
import 'package:nextpili/features/player/player_adapter.dart';
import 'package:nextpili/features/player/player_bottom_chrome.dart';
import 'package:nextpili/features/player/player_settings_local_state.dart';
import 'package:nextpili/features/player/player_settings_overlay.dart';
import 'package:nextpili/features/player/player_settings_quality_panel.dart';
import 'package:nextpili/features/player/player_settings_speed.dart';
import 'package:nextpili/l10n/app_localizations.dart';

const _sampleQualities = <StreamDto>[
  StreamDto(
    id: 'q80',
    codec: 'avc1',
    bandwidth: 4_000_000,
    qualityLabel: '1080P',
    qn: 80,
    height: 1080,
    url: 'https://example.test/1080',
    backupUrls: [],
  ),
  StreamDto(
    id: 'q64',
    codec: 'avc1',
    bandwidth: 2_000_000,
    qualityLabel: '720P',
    qn: 64,
    height: 720,
    url: 'https://example.test/720',
    backupUrls: [],
  ),
  StreamDto(
    id: 'q32',
    codec: 'avc1',
    bandwidth: 1_000_000,
    qualityLabel: '480P',
    qn: 32,
    height: 480,
    url: 'https://example.test/480',
    backupUrls: [],
  ),
];

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        extensions: const [PlayerColors.standard],
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }

  Widget overlay({
    required PlayerSettingsLocalState local,
    required ValueChanged<PlayerSettingsLocalState> onLocalChanged,
    ValueChanged<double>? onSpeed,
    ValueChanged<StreamDto>? onQuality,
    double currentSpeed = 1.0,
    String speedLabel = '1x',
    String qualityLabel = '1080P',
    String? currentQualityId = 'q80',
    List<StreamDto>? qualities,
  }) {
    final qualityList = qualities ?? _sampleQualities;
    return PlayerSettingsOverlay(
      colors: PlayerColors.standard,
      local: local,
      onLocalChanged: onLocalChanged,
      qualityLabel: qualityLabel,
      speedLabel: speedLabel,
      currentSpeed: currentSpeed,
      currentQualityId: currentQualityId,
      subtitleLabel: 'Off',
      qualities: qualityList,
      subtitleTracks: const [],
      onQuality: onQuality ?? (_) {},
      onSpeed: onSpeed ?? (_) {},
      onSubtitle: (_) {},
    );
  }

  testWidgets('renders toggle and value rows with localized labels',
      (tester) async {
    var local = const PlayerSettingsLocalState();
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
            );
          },
        ),
      ),
    );

    expect(find.text('Stable volume'), findsOneWidget);
    expect(find.text('Voice boost'), findsOneWidget);
    expect(find.text('Ambient mode'), findsOneWidget);
    expect(find.text('Subtitles'), findsOneWidget);
    expect(find.text('Sleep timer'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('1080P'), findsOneWidget);
    expect(find.text('1x'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(3));
  });

  testWidgets('switch rows update local state only', (tester) async {
    var local = const PlayerSettingsLocalState();
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
              speedLabel: '1x',
            );
          },
        ),
      ),
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(local.stableVolume, isTrue);
    expect(local.voiceBoost, isFalse);
  });

  testWidgets('host fades with visibility', (tester) async {
    await tester.pumpWidget(
      wrap(
        PlayerSettingsOverlayHost(
          visible: true,
          child: const Text('panel-body'),
        ),
      ),
    );
    expect(find.text('panel-body'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        PlayerSettingsOverlayHost(
          visible: false,
          child: const Text('panel-body'),
        ),
      ),
    );
    await tester.pump();
    final opacity = tester.widget<AnimatedOpacity>(
      find.byType(AnimatedOpacity),
    );
    expect(opacity.opacity, 0);
  });

  // Regression: RenderFractionalTranslation.hitTestChildren asserted
  // `!debugNeedsLayout` when a pointer hit the settings plate mid-animation
  // (AnimatedSlide / SlideTransition). Host + panel switch must use
  // Transform.translate so hit tests never touch FractionalTranslation.
  testWidgets('pointer during host open animation does not assert',
      (tester) async {
    var visible = false;
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: TextButton(
                    onPressed: () => setState(() => visible = !visible),
                    child: const Text('toggle-settings'),
                  ),
                ),
                Positioned(
                  top: 48,
                  right: 8,
                  bottom: 48,
                  width: 280,
                  child: PlayerSettingsOverlayHost(
                    visible: visible,
                    // Non-interactive body: assert is about hit-test safety,
                    // not row navigation.
                    child: const SizedBox(
                      width: 280,
                      height: 200,
                      child: ColoredBox(
                        color: Color(0xFF222222),
                        child: Center(child: Text('panel-body')),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('toggle-settings'));
    // Mid-animation pointer spam — previously tripped
    // RenderFractionalTranslation `!debugNeedsLayout`.
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final center = tester.getCenter(find.byType(PlayerSettingsOverlayHost));
      await tester.tapAt(center);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('panel-body'), findsOneWidget);
    // Host slide is Transform-based, not AnimatedSlide.
    expect(
      find.descendant(
        of: find.byType(PlayerSettingsOverlayHost),
        matching: find.byType(AnimatedSlide),
      ),
      findsNothing,
    );
  });

  testWidgets('pointer during sub-panel switch does not assert',
      (tester) async {
    var local = const PlayerSettingsLocalState();
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Quality'));
    // Do not settle — hit while AnimatedSwitcher transition is running.
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tapAt(tester.getCenter(find.byType(PlayerSettingsOverlay)));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Panel body still mounted; quality list should be reachable after settle.
    expect(find.text('720P'), findsOneWidget);
  });

  testWidgets('sleep timer nested list updates local minutes', (tester) async {
    var local = const PlayerSettingsLocalState();
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Sleep timer'));
    await tester.pumpAndSettle();
    expect(find.text('End of video'), findsOneWidget);
    await tester.tap(find.text('15m'));
    await tester.pumpAndSettle();
    expect(local.sleepTimerMinutes, 15);
  });

  testWidgets('sleep timer end of video option', (tester) async {
    var local = const PlayerSettingsLocalState();
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Sleep timer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End of video'));
    await tester.pumpAndSettle();
    expect(
      local.sleepTimerMinutes,
      PlayerSettingsLocalState.sleepTimerEndOfVideo,
    );
  });

  testWidgets('subtitle nested list calls onSubtitle', (tester) async {
    SubtitleTrackDto? selected;
    final tracks = [
      const SubtitleTrackDto(
        id: 'zh',
        label: 'Chinese',
        lang: 'zh-CN',
        url: 'https://example.test/zh.vtt',
      ),
    ];
    var local = const PlayerSettingsLocalState();
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return PlayerSettingsOverlay(
              colors: PlayerColors.standard,
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
              qualityLabel: '1080P',
              speedLabel: '1x',
              currentSpeed: 1.0,
              subtitleLabel: 'Off',
              qualities: _sampleQualities,
              subtitleTracks: tracks,
              onQuality: (_) {},
              onSpeed: (_) {},
              onSubtitle: (t) => selected = t,
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Subtitles'));
    await tester.pumpAndSettle();
    expect(find.text('Chinese'), findsOneWidget);
    await tester.tap(find.text('Chinese'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'zh');
  });

  testWidgets(
    'constrained height does not overflow and scrolls to bottom rows',
    (tester) async {
      // 7×44 rows + vertical padding ≈ 316; host like PlayerPane gutter leaves ~200.
      const constrainedHeight = 200.0;
      var local = const PlayerSettingsLocalState();

      await tester.pumpWidget(
        wrap(
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: kPlayerSettingsPanelWidth,
              height: constrainedHeight,
              child: overlay(
                local: local,
                onLocalChanged: (s) => local = s,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsWidgets);
      expect(find.text('Stable volume'), findsOneWidget);

      // Bottom value row must remain reachable via scroll (not clipped away).
      await tester.scrollUntilVisible(
        find.text('Quality'),
        40,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Quality'), findsOneWidget);
      expect(find.text('1080P'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('speed row opens nested panel; back returns to list',
      (tester) async {
    var local = const PlayerSettingsLocalState();
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
              currentSpeed: 1.0,
              speedLabel: '1x',
            );
          },
        ),
      ),
    );

    expect(find.text('Stable volume'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();

    expect(find.text('Stable volume'), findsNothing);
    expect(find.byType(Slider), findsOneWidget);
    // Centered rate + selected chip both show the label.
    expect(find.text('1x'), findsWidgets);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Stable volume'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Quality'), findsOneWidget);
  });

  testWidgets('quality row opens nested panel; select reports via onQuality',
      (tester) async {
    var local = const PlayerSettingsLocalState();
    final selected = <StreamDto>[];

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
              onQuality: (q) => setState(() => selected.add(q)),
            );
          },
        ),
      ),
    );

    expect(find.text('Stable volume'), findsOneWidget);

    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();

    expect(find.text('Stable volume'), findsNothing);
    expect(find.text('1080P'), findsOneWidget);
    expect(find.text('720P'), findsOneWidget);
    expect(find.text('480P'), findsOneWidget);
    // HD badge for 1080p ladder (qn ≥ 80).
    expect(find.text('HD'), findsOneWidget);

    await tester.tap(find.text('720P'));
    await tester.pumpAndSettle();
    expect(selected, hasLength(1));
    expect(selected.single.id, 'q64');

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Stable volume'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
  });

  test('playerQualityHdBadge uses qn and height thresholds', () {
    expect(
      playerQualityHdBadge(
        const StreamDto(
          id: 'a',
          codec: 'avc1',
          bandwidth: 1,
          qualityLabel: '1080P',
          qn: 80,
          url: 'u',
          backupUrls: [],
        ),
      ),
      'HD',
    );
    expect(
      playerQualityHdBadge(
        const StreamDto(
          id: 'b',
          codec: 'avc1',
          bandwidth: 1,
          qualityLabel: '720P',
          qn: 64,
          url: 'u',
          backupUrls: [],
        ),
      ),
      isNull,
    );
    expect(
      playerQualityHdBadge(
        const StreamDto(
          id: 'c',
          codec: 'avc1',
          bandwidth: 1,
          qualityLabel: '1080p',
          height: 1080,
          url: 'u',
          backupUrls: [],
        ),
      ),
      'HD',
    );
  });

  testWidgets(
    'seven speed chips stay on one row inside 280dp panel',
    (tester) async {
      var local = const PlayerSettingsLocalState();
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: kPlayerSettingsPanelWidth,
            child: overlay(
              local: local,
              onLocalChanged: (s) => local = s,
              currentSpeed: 1.0,
              speedLabel: '1x',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Speed'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Labels unique to the chip row (not duplicated by the centered rate).
      final chipOnly = ['0.5x', '0.75x', '1.25x', '1.5x', '1.75x', '2x'];
      for (final label in chipOnly) {
        expect(find.text(label), findsOneWidget);
      }

      final yRef = tester.getCenter(find.text('0.5x')).dy;
      for (final label in chipOnly.skip(1)) {
        expect(
          tester.getCenter(find.text(label)).dy,
          closeTo(yRef, 1.0),
          reason: '$label must share the same row as 0.5x',
        );
      }

      final left = tester.getTopLeft(find.text('0.5x')).dx;
      final right = tester.getTopRight(find.text('2x')).dx;
      expect(right - left, lessThanOrEqualTo(kPlayerSettingsPanelWidth));
      expect(find.byType(Wrap), findsNothing);
    },
  );

  testWidgets('chip selection reports rate via onSpeed only', (tester) async {
    var local = const PlayerSettingsLocalState();
    final speeds = <double>[];
    var current = 1.0;

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
              currentSpeed: current,
              speedLabel: playerSpeedLabel(current),
              onSpeed: (r) => setState(() {
                speeds.add(r);
                current = r;
              }),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1.5x'));
    await tester.pumpAndSettle();

    expect(speeds, [1.5]);
    expect(find.text('1.5x'), findsWidgets);
  });

  testWidgets('plus and minus step within speedOptions bounds', (tester) async {
    var local = const PlayerSettingsLocalState();
    final speeds = <double>[];
    var current = 1.0;
    final options = MediaKitPlayerAdapter.speedOptions;

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
              currentSpeed: current,
              speedLabel: playerSpeedLabel(current),
              onSpeed: (r) => setState(() {
                speeds.add(r);
                current = r;
              }),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Increase playback speed'));
    await tester.pumpAndSettle();
    expect(speeds.last, 1.25);

    await tester.tap(find.byTooltip('Decrease playback speed'));
    await tester.pumpAndSettle();
    expect(speeds.last, 1.0);

    // At minimum: further decrement is a no-op.
    current = options.first;
    speeds.clear();
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
              currentSpeed: current,
              speedLabel: playerSpeedLabel(current),
              onSpeed: (r) => setState(() {
                speeds.add(r);
                current = r;
              }),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Decrease playback speed'));
    await tester.pumpAndSettle();
    expect(speeds, isEmpty);

    // At maximum: further increment is a no-op.
    current = options.last;
    speeds.clear();
    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
              currentSpeed: current,
              speedLabel: playerSpeedLabel(current),
              onSpeed: (r) => setState(() {
                speeds.add(r);
                current = r;
              }),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase playback speed'));
    await tester.pumpAndSettle();
    expect(speeds, isEmpty);
  });

  testWidgets('slider value maps to discrete option index', (tester) async {
    var local = const PlayerSettingsLocalState();
    final speeds = <double>[];
    var current = 1.0;
    final options = MediaKitPlayerAdapter.speedOptions;

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return overlay(
              local: local,
              onLocalChanged: (s) => setState(() => local = s),
              currentSpeed: current,
              speedLabel: playerSpeedLabel(current),
              onSpeed: (r) => setState(() {
                speeds.add(r);
                current = r;
              }),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Speed'));
    await tester.pumpAndSettle();

    final slider = tester.widget<Slider>(find.byType(Slider));
    final expectedIndex = playerSpeedOptionIndex(1.0, options).toDouble();
    expect(slider.value, expectedIndex);
    expect(slider.max, (options.length - 1).toDouble());
    expect(slider.divisions, options.length - 1);

    // Drag toward the high end → last option.
    await tester.drag(find.byType(Slider), const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(speeds, isNotEmpty);
    expect(speeds.last, options.last);
    expect(
      tester.widget<Slider>(find.byType(Slider)).value,
      (options.length - 1).toDouble(),
    );
  });

  group('playerSpeedOptionIndex / playerSpeedStepRate', () {
    const options = MediaKitPlayerAdapter.speedOptions;

    test('exact and nearest index mapping', () {
      expect(playerSpeedOptionIndex(1.0, options), 2);
      expect(playerSpeedOptionIndex(1.5, options), 4);
      // 1.1 is closer to 1.0 than 1.25.
      expect(playerSpeedOptionIndex(1.1, options), 2);
    });

    test('step clamps at ends', () {
      expect(playerSpeedStepRate(0.5, options, delta: -1), isNull);
      expect(playerSpeedStepRate(2.0, options, delta: 1), isNull);
      expect(playerSpeedStepRate(1.0, options, delta: 1), 1.25);
      expect(playerSpeedStepRate(1.0, options, delta: -1), 0.75);
    });
  });
}
