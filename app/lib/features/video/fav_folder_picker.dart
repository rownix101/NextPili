import 'dart:async' show unawaited;

import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/loading.dart';
import '../../core/widgets/np_button.dart';
import '../../l10n/l10n.dart';

/// Multi-select favorite folders for one archive.
///
/// Returns applied [ArchiveRelationDto], or `null` if cancelled / no change.
Future<ArchiveRelationDto?> showFavFolderPicker({
  required BuildContext context,
  required int aid,
  required String bvid,
}) {
  return showDialog<ArchiveRelationDto>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => _FavFolderPickerDialog(aid: aid, bvid: bvid),
  );
}

class _FavFolderPickerDialog extends StatefulWidget {
  const _FavFolderPickerDialog({
    required this.aid,
    required this.bvid,
  });

  final int aid;
  final String bvid;

  @override
  State<_FavFolderPickerDialog> createState() => _FavFolderPickerDialogState();
}

class _FavFolderPickerDialogState extends State<_FavFolderPickerDialog> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<FavFolderDto> _folders = const [];
  final Set<int> _initial = {};
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await CoreApi.instance.favFolders(rid: widget.aid);
      if (!mounted) return;
      final folders = list.folders;
      final initial = <int>{};
      for (final f in folders) {
        if (f.inFolder) initial.add(i64(f.id));
      }
      setState(() {
        _folders = folders;
        _initial
          ..clear()
          ..addAll(initial);
        _selected
          ..clear()
          ..addAll(initial);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final add = _selected.difference(_initial).toList()..sort();
    final del = _initial.difference(_selected).toList()..sort();
    if (add.isEmpty && del.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      final rel = await CoreApi.instance.videoFavoriteDeal(
        aid: widget.aid,
        bvid: widget.bvid,
        addMediaIds: add,
        delMediaIds: del,
      );
      await Haptics.impactLight();
      if (!mounted) return;
      Navigator.of(context).pop(rel);
    } catch (e) {
      await Haptics.error();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(e, context.l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: colors.elevated,
      shape: RoundedRectangleBorder(borderRadius: AppShapes.borderLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.favFolderPickerTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.favFolderPickerHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.fgSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Flexible(child: _buildBody(theme, colors, l10n)),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: NpButton(
                      label: l10n.cancel,
                      variant: NpButtonVariant.secondary,
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: NpButton(
                      label: l10n.done,
                      loading: _saving,
                      onPressed: _loading || _saving || _folders.isEmpty
                          ? null
                          : _confirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    AppColors colors,
    AppLocalizations l10n,
  ) {
    if (_loading) {
      return const SizedBox(height: 160, child: AppLoading());
    }
    if (_folders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.inbox, size: AppIcons.lg, color: colors.fgMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.favFolderPickerEmpty,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.fgSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: _folders.length,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: colors.borderSubtle),
      itemBuilder: (context, i) {
        final f = _folders[i];
        final id = i64(f.id);
        final checked = _selected.contains(id);
        return CheckboxListTile(
          value: checked,
          onChanged: _saving
              ? null
              : (v) {
                  setState(() {
                    if (v == true) {
                      _selected.add(id);
                    } else {
                      _selected.remove(id);
                    }
                  });
                  unawaited(Haptics.selection());
                },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text(f.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            l10n.favFolderMediaCount(f.mediaCount),
            style: theme.textTheme.labelSmall?.copyWith(color: colors.fgMuted),
          ),
        );
      },
    );
  }
}
