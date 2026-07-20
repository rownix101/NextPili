import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/player_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';
import '../player/player_adapter.dart';

/// Live room watch page: metadata + media_kit stream.
class LiveRoomPage extends StatefulWidget {
  const LiveRoomPage({
    super.key,
    required this.roomId,
    this.title = '',
  });

  final int roomId;
  final String title;

  @override
  State<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends State<LiveRoomPage> {
  late final MediaKitPlayerAdapter _adapter;
  LiveRoomDto? _room;
  bool _loading = true;
  String? _error;
  bool _showChrome = true;
  int _qn = 0;

  @override
  void initState() {
    super.initState();
    _adapter = MediaKitPlayerAdapter();
    _load();
  }

  @override
  void dispose() {
    _adapter.dispose();
    super.dispose();
  }

  Future<void> _load({int? qn}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roomFuture = CoreApi.instance.liveRoom(widget.roomId);
      final playFuture = CoreApi.instance.livePlayUrl(
        roomId: widget.roomId,
        qn: qn ?? _qn,
      );
      final room = await roomFuture;
      final source = await playFuture;
      if (!mounted) return;
      await _adapter.open(source);
      if (!mounted) return;
      setState(() {
        _room = room;
        _qn = qn ?? _qn;
        if (_qn == 0 && source.requestedQn != null) {
          _qn = source.requestedQn!;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      try {
        final room = await CoreApi.instance.liveRoom(widget.roomId);
        if (mounted) _room = room;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  Future<void> _switchQuality(StreamDto stream) async {
    final q = stream.qn;
    if (q == null) {
      await _adapter.setQuality(stream.id);
      if (mounted) setState(() {});
      return;
    }
    setState(() => _qn = q);
    await _load(qn: q);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final player = PlayerColors.of(context);
    final l10n = context.l10n;
    final room = _room;
    final title = room?.title.isNotEmpty == true
        ? room!.title
        : (widget.title.isNotEmpty ? widget.title : l10n.liveTitle);
    final uname = room?.uname ?? '';
    final online = room != null ? i64(room.online) : 0;
    final liveStatus = room?.liveStatus ?? 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showChrome = !_showChrome),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_loading)
                      const ColoredBox(
                        color: Colors.black,
                        child: Center(child: AppLoading()),
                      )
                    else if (_error != null)
                      ColoredBox(
                        color: Colors.black,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppIcons.alert,
                                    color: player.controlFg, size: 36),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: player.controlFg),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                NpButton(
                                  label: l10n.retry,
                                  onPressed: () => _load(qn: _qn),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Video(
                        controller: _adapter.controller,
                        controls: NoVideoControls,
                      ),
                    if (_showChrome)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.65),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              NpIconButton(
                                tooltip: l10n.back,
                                icon: AppIcons.arrowLeft,
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.go('/live');
                                  }
                                },
                              ),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: player.controlFg,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (_adapter.qualityOptions.length > 1)
                                PopupMenuButton<StreamDto>(
                                  tooltip: l10n.playerQuality,
                                  icon: Icon(AppIcons.highQuality,
                                      color: player.controlFg),
                                  onSelected: _switchQuality,
                                  itemBuilder: (context) {
                                    return _adapter.qualityOptions
                                        .map(
                                          (s) => PopupMenuItem(
                                            value: s,
                                            child: Text(s.qualityLabel),
                                          ),
                                        )
                                        .toList();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Material(
              color: colors.elevated,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (liveStatus == 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.live,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.liveBadge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else
                          Text(
                            liveStatus == 2
                                ? l10n.liveRound
                                : l10n.liveOffline,
                            style: TextStyle(color: colors.fgSecondary),
                          ),
                        if (online > 0) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Icon(AppIcons.eye,
                              size: 16, color: colors.fgSecondary),
                          const SizedBox(width: 4),
                          Text(
                            l10n.liveOnline(formatCount(online)),
                            style: TextStyle(color: colors.fgSecondary),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (uname.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        uname,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.fgSecondary,
                            ),
                      ),
                    ],
                    if (room?.areaName.isNotEmpty == true) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        room!.areaName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colors.fgMuted,
                            ),
                      ),
                    ],
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
