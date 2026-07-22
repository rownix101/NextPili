import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/icons/app_icons.dart';
import '../../core/motion/app_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/glass/app_glass.dart';
import '../../l10n/l10n.dart';
import 'fav_folder_picker.dart';

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

/// [GlassDialog.show] uses root navigator; pop must match or the page route exits.
void popRootDialog<T>(BuildContext context, [T? value]) {
  Navigator.of(context, rootNavigator: true).pop(value);
}

/// Login gate dialog — interaction §8 + design-system §8.6 (GlassDialog).
Future<bool> ensureLoggedIn(BuildContext context) async {
  if (isLoggedIn()) return true;
  final l10n = context.l10n;
  final go = await GlassDialog.show<bool>(
    context: context,
    title: l10n.loginRequiredTitle,
    message: l10n.loginRequiredBody,
    barrierDismissible: true,
    maxWidth: 320,
    actions: [
      GlassDialogAction(
        label: l10n.cancel,
        onPressed: () => popRootDialog(context, false),
      ),
      GlassDialogAction(
        label: l10n.goLogin,
        isPrimary: true,
        onPressed: () => popRootDialog(context, true),
      ),
    ],
  );
  if (go == true && context.mounted) {
    context.push('/auth');
  }
  return false;
}

bool isAlreadyLikedError(Object error) {
  if (error is! AppError) return false;
  final code = error.biliCode;
  if (code == 65006) return true;
  final m = error.message;
  return m.contains('重复') || m.contains('已赞') || m.contains('已经点赞');
}

bool isNotLikedError(Object error) {
  if (error is! AppError) return false;
  final code = error.biliCode;
  if (code == 65004) return true;
  final m = error.message;
  return m.contains('未点赞') || m.contains('还没有点赞') || m.contains('取消点赞失败');
}

/// Like / coin / favorite / share row under the player.
///
/// design-system §7.7: icon + count; login gate with text.
/// interaction §6: haptics + snackbar; motion §4.5: like bounce.
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

  bool? _likedOverride;
  int? _coinOverride;
  bool? _favOverride;

  @override
  void initState() {
    super.initState();
    _syncCounts(widget.stat);
  }

  @override
  void didUpdateWidget(covariant EngagementBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aid != widget.aid || oldWidget.bvid != widget.bvid) {
      _likedOverride = null;
      _coinOverride = null;
      _favOverride = null;
      _syncCounts(widget.stat);
    } else if (oldWidget.stat != widget.stat) {
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

  bool _likedOf(ArchiveRelationDto? rel) =>
      _likedOverride ?? rel?.liked ?? false;

  int _coinOf(ArchiveRelationDto? rel) => _coinOverride ?? rel?.coin ?? 0;

  bool _favOf(ArchiveRelationDto? rel) =>
      _favOverride ?? rel?.favorited ?? false;

  void _applyRelation(ArchiveRelationDto rel) {
    _likedOverride = rel.liked;
    _coinOverride = rel.coin;
    _favOverride = rel.favorited;
  }

  void _toast(String msg, {SnackBarAction? action}) {
    if (!mounted) return;
    AppSnackBar.show(context, message: msg, action: action);
  }

  Future<void> _onLike(ArchiveRelationDto? rel) async {
    if (_busy) return;
    if (!await ensureLoggedIn(context)) return;
    final next = !_likedOf(rel);
    final prevCount = _likeCount;
    final prevLiked = _likedOf(rel);
    setState(() {
      _busy = true;
      _likedOverride = next;
      _likeCount = next
          ? _likeCount + 1
          : (_likeCount - 1).clamp(0, 1 << 30);
    });
    unawaited(Haptics.impactLight());
    try {
      final result = await CoreApi.instance.videoLike(
        aid: widget.aid,
        bvid: widget.bvid,
        like: next,
      );
      if (!mounted) return;
      setState(() => _applyRelation(result));
      ref.invalidate(videoRelationProvider(_key));
    } catch (e) {
      if (!mounted) return;
      if (next && isAlreadyLikedError(e)) {
        setState(() => _likedOverride = true);
        ref.invalidate(videoRelationProvider(_key));
        return;
      }
      if (!next && isNotLikedError(e)) {
        setState(() {
          _likedOverride = false;
          _likeCount = prevCount;
        });
        ref.invalidate(videoRelationProvider(_key));
        return;
      }
      setState(() {
        _likedOverride = prevLiked;
        _likeCount = prevCount;
      });
      await Haptics.error();
      if (!mounted) return;
      _toast(errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onCoin(ArchiveRelationDto? rel) async {
    if (_busy) return;
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    final already = _coinOf(rel);
    if (already >= 2) {
      await Haptics.warning();
      if (!mounted) return;
      _toast(context.l10n.coinAlreadyMax);
      return;
    }
    final l10n = context.l10n;
    final multiply = await GlassDialog.show<int>(
      context: context,
      title: l10n.coinDialogTitle,
      barrierDismissible: true,
      maxWidth: 320,
      actions: [
        if (already < 1)
          GlassDialogAction(
            label: l10n.coinOne,
            onPressed: () => popRootDialog(context, 1),
          ),
        if (already <= 1)
          GlassDialogAction(
            label: already == 0 ? l10n.coinTwo : l10n.coinOne,
            isPrimary: true,
            onPressed: () => popRootDialog(context, 2 - already),
          ),
        GlassDialogAction(
          label: l10n.cancel,
          onPressed: () => popRootDialog<int>(context),
        ),
      ],
    );
    if (multiply == null || multiply <= 0 || !mounted) return;
    final alsoLike = !_likedOf(rel);
    final prevLike = _likeCount;
    final prevCoin = _coinCount;
    final prevLiked = _likedOf(rel);
    final prevCoinFlag = _coinOf(rel);
    setState(() {
      _busy = true;
      _coinCount += multiply;
      _coinOverride = (prevCoinFlag + multiply).clamp(1, 2);
      if (alsoLike) {
        _likeCount += 1;
        _likedOverride = true;
      }
    });
    unawaited(Haptics.impactLight());
    try {
      final result = await CoreApi.instance.videoCoin(
        aid: widget.aid,
        bvid: widget.bvid,
        multiply: multiply,
        alsoLike: alsoLike,
      );
      if (!mounted) return;
      setState(() => _applyRelation(result));
      ref.invalidate(videoRelationProvider(_key));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _likeCount = prevLike;
        _coinCount = prevCoin;
        _likedOverride = prevLiked;
        _coinOverride = prevCoinFlag > 0 ? prevCoinFlag : null;
      });
      await Haptics.error();
      if (!mounted) return;
      _toast(errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onFavorite(ArchiveRelationDto? rel) async {
    if (_busy) return;
    if (!await ensureLoggedIn(context)) return;
    final next = !_favOf(rel);
    final prev = _favCount;
    final prevFav = _favOf(rel);
    setState(() {
      _busy = true;
      _favOverride = next;
      _favCount = next ? _favCount + 1 : (_favCount - 1).clamp(0, 1 << 30);
    });
    unawaited(Haptics.impactLight());
    try {
      final result = await CoreApi.instance.videoFavorite(
        aid: widget.aid,
        bvid: widget.bvid,
        favorite: next,
      );
      if (!mounted) return;
      setState(() => _applyRelation(result));
      ref.invalidate(videoRelationProvider(_key));
      if (next) {
        _toast(context.l10n.favoriteAdded);
      } else {
        _toast(
          context.l10n.favoriteRemoved,
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () {
              unawaited(_restoreFavorite());
            },
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _favOverride = prevFav;
        _favCount = prev;
      });
      await Haptics.error();
      if (!mounted) return;
      _toast(errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFavorite() async {
    if (_busy) return;
    final prev = _favCount;
    setState(() {
      _busy = true;
      _favOverride = true;
      _favCount = prev + 1;
    });
    try {
      final result = await CoreApi.instance.videoFavorite(
        aid: widget.aid,
        bvid: widget.bvid,
        favorite: true,
      );
      if (!mounted) return;
      setState(() => _applyRelation(result));
      ref.invalidate(videoRelationProvider(_key));
      await Haptics.impactLight();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _favOverride = false;
        _favCount = prev;
      });
      await Haptics.error();
      if (!mounted) return;
      _toast(errorMessage(e, context.l10n));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onFavoriteLongPress(ArchiveRelationDto? rel) async {
    if (_busy) return;
    if (!await ensureLoggedIn(context)) return;
    if (!mounted) return;
    await Haptics.impactMedium();
    if (!mounted) return;
    final wasFav = _favOf(rel);
    final prev = _favCount;
    final result = await showFavFolderPicker(
      context: context,
      aid: widget.aid,
      bvid: widget.bvid,
    );
    if (!mounted || result == null) return;
    setState(() {
      _applyRelation(result);
      final nowFav = result.favorited;
      if (!wasFav && nowFav) {
        _favCount = prev + 1;
      } else if (wasFav && !nowFav) {
        _favCount = (prev - 1).clamp(0, 1 << 30);
      }
    });
    ref.invalidate(videoRelationProvider(_key));
    final l10n = context.l10n;
    final nowFav = result.favorited;
    if (nowFav && !wasFav) {
      _toast(l10n.favoriteAdded);
    } else if (!nowFav && wasFav) {
      _toast(l10n.favoriteRemoved);
    } else if (nowFav) {
      _toast(l10n.favoriteAdded);
    }
  }

  Future<void> _onShare() async {
    final url = widget.bvid.isNotEmpty
        ? 'https://www.bilibili.com/video/${widget.bvid}'
        : 'https://www.bilibili.com/video/av${widget.aid}';
    await Clipboard.setData(ClipboardData(text: url));
    await Haptics.impactLight();
    if (mounted) _toast(context.l10n.linkCopied);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final relAsync = ref.watch(videoRelationProvider(_key));
    final rel = relAsync.asData?.value;
    final liked = _likedOf(rel);
    final coin = _coinOf(rel);
    final favorited = _favOf(rel);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.borderSubtle)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final row = Row(
                children: [
                  _EngagementAction(
                    icon: AppIcons.like,
                    countLabel: formatCount(_likeCount, locale: locale),
                    tooltip: l10n.statLike,
                    active: liked,
                    enabled: !_busy,
                    bounceOnActivate: true,
                    onTap: () => _onLike(rel),
                  ),
                  _EngagementAction(
                    icon: AppIcons.coin,
                    countLabel: formatCount(_coinCount, locale: locale),
                    tooltip: l10n.statCoin,
                    active: coin > 0,
                    enabled: !_busy,
                    onTap: () => _onCoin(rel),
                  ),
                  _EngagementAction(
                    icon: AppIcons.star,
                    countLabel: formatCount(_favCount, locale: locale),
                    tooltip:
                        '${l10n.statFavorite} · ${l10n.statFavoriteLongPress}',
                    active: favorited,
                    enabled: !_busy,
                    bounceOnActivate: true,
                    onTap: () => _onFavorite(rel),
                    onLongPress: () => _onFavoriteLongPress(rel),
                  ),
                  _EngagementAction(
                    icon: AppIcons.share,
                    countLabel: formatCount(_shareCount, locale: locale),
                    tooltip: l10n.statShare,
                    active: false,
                    enabled: true,
                    onTap: _onShare,
                  ),
                  const Spacer(),
                  Semantics(
                    label:
                        '${l10n.statReply} ${formatCount(i64(widget.stat.reply), locale: locale)}',
                    child: Text(
                      '${l10n.statReply} ${formatCount(i64(widget.stat.reply), locale: locale)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colors.fgSecondary,
                      ),
                    ),
                  ),
                ],
              );
              if (!constraints.maxWidth.isFinite ||
                  constraints.maxWidth >= 360) {
                return row;
              }
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: row,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Icon + count control (design-system §7.7). Tooltip + Semantics; form
/// difference on active (tinted chip, not color alone).
class _EngagementAction extends StatefulWidget {
  const _EngagementAction({
    required this.icon,
    required this.countLabel,
    required this.tooltip,
    required this.active,
    required this.enabled,
    required this.onTap,
    this.onLongPress,
    this.bounceOnActivate = false,
  });

  final IconData icon;
  final String countLabel;
  final String tooltip;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool bounceOnActivate;

  @override
  State<_EngagementAction> createState() => _EngagementActionState();
}

class _EngagementActionState extends State<_EngagementAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(vsync: this, duration: AppDuration.short3);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 1.07,
        ).chain(CurveTween(curve: AppEasing.standardDecelerate)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.07,
          end: 1,
        ).chain(CurveTween(curve: AppEasing.standard)),
        weight: 55,
      ),
    ]).animate(_bounce);
  }

  @override
  void didUpdateWidget(covariant _EngagementAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bounceOnActivate &&
        widget.active &&
        !oldWidget.active &&
        !MediaQuery.disableAnimationsOf(context)) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = widget.active ? colors.accent : colors.fgPrimary;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final body = ScaleTransition(
      scale: reduceMotion ? const AlwaysStoppedAnimation(1) : _scale,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          onLongPress: widget.enabled ? widget.onLongPress : null,
          borderRadius: AppShapes.borderSm,
          hoverColor: colors.fgPrimary.withValues(alpha: 0.06),
          focusColor: colors.accent.withValues(alpha: 0.12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: reduceMotion ? Duration.zero : AppDuration.short2,
                    curve: AppEasing.standard,
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: widget.active
                          ? colors.accent.withValues(alpha: 0.14)
                          : colors.fgPrimary.withValues(alpha: 0),
                      borderRadius: AppShapes.borderSm,
                    ),
                    child: Icon(widget.icon, size: AppIcons.sm, color: color),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    widget.countLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: widget.active
                          ? FontWeight.w600
                          : FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Tooltip(
        message: widget.tooltip,
        child: Semantics(
          button: true,
          enabled: widget.enabled,
          selected: widget.active,
          label: '${widget.tooltip} ${widget.countLabel}',
          child: body,
        ),
      ),
    );
  }
}
