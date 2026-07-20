import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../l10n/l10n.dart';

/// Key for relation provider: `aid|bvid`.
String relationKey(int aid, String bvid) => '$aid|$bvid';

/// Current viewer's like / coin / fav / follow flags.
final videoRelationProvider = FutureProvider.autoDispose
    .family<ArchiveRelationDto, String>((ref, key) async {
  final parts = key.split('|');
  final aid = int.tryParse(parts.first) ?? 0;
  final bvid = parts.length > 1 ? parts.sublist(1).join('|') : '';
  return CoreApi.instance.videoRelation(aid: aid, bvid: bvid);
});

bool isLoggedIn() {
  try {
    return CoreApi.instance.listAccounts().any((a) => a.isLogin);
  } catch (_) {
    return false;
  }
}

/// Like / coin / favorite / share row under the player.
class EngagementBar extends ConsumerStatefulWidget {
  const EngagementBar({
    super.key,
    required this.aid,
    required this.bvid,
    required this.stat,
  });

  final int aid;
  final String bvid;
  final VideoStatDto stat;

  @override
  ConsumerState<EngagementBar> createState() => _EngagementBarState();
}

class _EngagementBarState extends ConsumerState<EngagementBar> {
  bool _busy = false;
  late int _likeCount;
  late int _coinCount;
  late int _favCount;
  late int _shareCount;

  @override
  void initState() {
    super.initState();
    _syncCounts(widget.stat);
  }

  @override
  void didUpdateWidget(covariant EngagementBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stat != widget.stat) {
      _syncCounts(widget.stat);
    }
  }

  void _syncCounts(VideoStatDto s) {
    _likeCount = i64(s.like);
    _coinCount = i64(s.coin);
    _favCount = i64(s.favorite);
    _shareCount = i64(s.share);
  }

  String get _key => relationKey(widget.aid, widget.bvid);

  Future<bool> _ensureLogin() async {
    if (isLoggedIn()) return true;
    final l10n = context.l10n;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.loginRequiredTitle),
        content: Text(l10n.loginRequiredBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.goLogin),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      context.push('/auth');
    }
    return false;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _onLike(ArchiveRelationDto? rel) async {
    if (_busy) return;
    if (!await _ensureLogin()) return;
    final next = !(rel?.liked ?? false);
    final prev = _likeCount;
    setState(() {
      _busy = true;
      _likeCount = next ? _likeCount + 1 : (_likeCount - 1).clamp(0, 1 << 30);
    });
    try {
      await CoreApi.instance.videoLike(
        aid: widget.aid,
        bvid: widget.bvid,
        like: next,
      );
      ref.invalidate(videoRelationProvider(_key));
    } catch (e) {
      if (mounted) {
        setState(() => _likeCount = prev);
        _toast(errorMessage(e, context.l10n));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onCoin(ArchiveRelationDto? rel) async {
    if (_busy) return;
    if (!await _ensureLogin()) return;
    if (!mounted) return;
    final already = rel?.coin ?? 0;
    if (already >= 2) {
      _toast(context.l10n.coinAlreadyMax);
      return;
    }
    final multiply = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return SimpleDialog(
          title: Text(l10n.coinDialogTitle),
          children: [
            if (already < 1)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 1),
                child: Text(l10n.coinOne),
              ),
            if (already <= 1)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 2 - already),
                child: Text(already == 0 ? l10n.coinTwo : l10n.coinOne),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
    if (multiply == null || multiply <= 0 || !mounted) return;
    final alsoLike = !(rel?.liked ?? false);
    final prevLike = _likeCount;
    final prevCoin = _coinCount;
    setState(() {
      _busy = true;
      _coinCount += multiply;
      if (alsoLike) _likeCount += 1;
    });
    try {
      await CoreApi.instance.videoCoin(
        aid: widget.aid,
        bvid: widget.bvid,
        multiply: multiply,
        alsoLike: alsoLike,
      );
      ref.invalidate(videoRelationProvider(_key));
    } catch (e) {
      if (mounted) {
        setState(() {
          _likeCount = prevLike;
          _coinCount = prevCoin;
        });
        _toast(errorMessage(e, context.l10n));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onFavorite(ArchiveRelationDto? rel) async {
    if (_busy) return;
    if (!await _ensureLogin()) return;
    final next = !(rel?.favorited ?? false);
    final prev = _favCount;
    setState(() {
      _busy = true;
      _favCount = next ? _favCount + 1 : (_favCount - 1).clamp(0, 1 << 30);
    });
    try {
      await CoreApi.instance.videoFavorite(
        aid: widget.aid,
        bvid: widget.bvid,
        favorite: next,
      );
      ref.invalidate(videoRelationProvider(_key));
      if (mounted) {
        _toast(next ? context.l10n.favoriteAdded : context.l10n.favoriteRemoved);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _favCount = prev);
        _toast(errorMessage(e, context.l10n));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onShare() async {
    final url = widget.bvid.isNotEmpty
        ? 'https://www.bilibili.com/video/${widget.bvid}'
        : 'https://www.bilibili.com/video/av${widget.aid}';
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) _toast(context.l10n.linkCopied);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final relAsync = ref.watch(videoRelationProvider(_key));
    final rel = relAsync.asData?.value;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          _Action(
            icon: AppIcons.like,
            label: formatCount(_likeCount, locale: locale),
            tooltip: l10n.statLike,
            active: rel?.liked ?? false,
            enabled: !_busy,
            onTap: () => _onLike(rel),
          ),
          _Action(
            icon: AppIcons.coin,
            label: formatCount(_coinCount, locale: locale),
            tooltip: l10n.statCoin,
            active: (rel?.coin ?? 0) > 0,
            enabled: !_busy,
            onTap: () => _onCoin(rel),
          ),
          _Action(
            icon: AppIcons.star,
            label: formatCount(_favCount, locale: locale),
            tooltip: l10n.statFavorite,
            active: rel?.favorited ?? false,
            enabled: !_busy,
            onTap: () => _onFavorite(rel),
          ),
          _Action(
            icon: AppIcons.share,
            label: formatCount(_shareCount, locale: locale),
            tooltip: l10n.statShare,
            active: false,
            enabled: true,
            onTap: _onShare,
          ),
          const Spacer(),
          Text(
            '${l10n.statReply} ${formatCount(i64(widget.stat.reply), locale: locale)}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.fgSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = active ? colors.accent : colors.fgPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
