import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/content_surface.dart';
import '../../l10n/l10n.dart';

/// Multi-P list on the watch-page right rail — interaction §4.0 / §4.5.
///
/// Opaque elevated surface (not glass) — design-system §2.
class PartsPanel extends StatelessWidget {
  const PartsPanel({
    super.key,
    required this.pages,
    required this.currentCid,
    required this.onSelect,
  });

  final List<VideoPageDto> pages;
  final int currentCid;
  final ValueChanged<VideoPageDto> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;

    if (pages.isEmpty) {
      return ContentSurface(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          l10n.videoPartsEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.fgSecondary,
          ),
        ),
      );
    }

    final currentIndex =
        pages.indexWhere((p) => i64(p.cid) == currentCid).clamp(0, pages.length - 1) +
            1;

    return ContentSurface(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.videoPartsCount(pages.length),
                  style: theme.textTheme.titleSmall,
                ),
              ),
              Text(
                '$currentIndex/${pages.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.fgSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: pages.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, i) {
                final p = pages[i];
                final cid = i64(p.cid);
                final selected = cid == currentCid;
                final title = p.part_.isEmpty
                    ? l10n.videoPartFallback(p.page)
                    : p.part_;
                return Material(
                  color: selected
                      ? colors.accent.withValues(alpha: 0.12)
                      : colors.sunken,
                  borderRadius: AppShapes.borderSm,
                  child: InkWell(
                    borderRadius: AppShapes.borderSm,
                    hoverColor: colors.fgPrimary.withValues(alpha: 0.04),
                    focusColor: colors.accent.withValues(alpha: 0.12),
                    onTap: selected
                        ? null
                        : () {
                            Haptics.selection();
                            onSelect(p);
                          },
                    child: Semantics(
                      button: true,
                      selected: selected,
                      label: title,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: selected
                                  ? Icon(
                                      AppIcons.play,
                                      size: AppIcons.xs,
                                      color: colors.accent,
                                    )
                                  : Text(
                                      '${p.page}',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(color: colors.fgMuted),
                                    ),
                            ),
                            const SizedBox(width: AppSpacing.xs + 2),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: selected
                                      ? colors.accent
                                      : colors.fgPrimary,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              formatDurationMs(
                                i64(p.durationMs),
                                emptyAsZero: true,
                              ),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.fgMuted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
