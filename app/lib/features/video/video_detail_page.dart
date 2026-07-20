import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../bridge/core_api.dart';

final videoDetailProvider =
    FutureProvider.autoDispose.family<VideoDetailDto, String>((ref, id) {
  return CoreApi.instance.videoDetail(id);
});

class VideoDetailPage extends ConsumerWidget {
  const VideoDetailPage({super.key, required this.videoId});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(videoDetailProvider(videoId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('稿件详情'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(errorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(videoDetailProvider(videoId)),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (detail) => _DetailBody(detail: detail, theme: theme),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.theme});

  final VideoDetailDto detail;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final cover = _Cover(url: detail.cover);
        final info = _InfoColumn(detail: detail, theme: theme);

        if (wide) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: cover),
                const SizedBox(width: 24),
                Expanded(flex: 6, child: info),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: cover),
            const SizedBox(height: 16),
            info,
          ],
        );
      },
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url.isEmpty
          ? ColoredBox(
              color: theme.colorScheme.surfaceContainerHigh,
              child: const Center(child: Icon(Icons.movie_outlined, size: 48)),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, error, stackTrace) => ColoredBox(
                color: theme.colorScheme.surfaceContainerHigh,
                child: const Center(
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.detail, required this.theme});

  final VideoDetailDto detail;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final stat = detail.stat;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(detail.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          detail.bvid.isNotEmpty ? detail.bvid : 'av${i64(detail.aid)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage:
                  detail.ownerFace.isNotEmpty ? NetworkImage(detail.ownerFace) : null,
              child: detail.ownerFace.isEmpty
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                detail.ownerName,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _StatChip(icon: Icons.play_arrow_outlined, label: _fmt(i64(stat.view))),
            _StatChip(icon: Icons.thumb_up_outlined, label: _fmt(i64(stat.like))),
            _StatChip(icon: Icons.comment_outlined, label: _fmt(i64(stat.reply))),
            _StatChip(icon: Icons.subtitles_outlined, label: _fmt(i64(stat.danmaku))),
            _StatChip(icon: Icons.star_outline, label: _fmt(i64(stat.favorite))),
            _StatChip(icon: Icons.monetization_on_outlined, label: _fmt(i64(stat.coin))),
          ],
        ),
        const SizedBox(height: 16),
        Text('简介', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        SelectableText(
          detail.desc.isEmpty ? '（无简介）' : detail.desc,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Text(
          '分 P（${detail.pages.length}）',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (detail.pages.isEmpty)
          Text(
            '无分 P 信息',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          ...detail.pages.map(
            (p) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                child: Text('${p.page}', style: theme.textTheme.labelSmall),
              ),
              title: Text(p.part_.isEmpty ? 'P${p.page}' : p.part_),
              subtitle: Text(
                'cid ${i64(p.cid)} · ${_formatDuration(i64(p.durationMs))}',
              ),
              trailing: const Icon(Icons.play_circle_outline),
              onTap: () => _openPlayer(context, detail, i64(p.cid)),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton.tonalIcon(
          onPressed: detail.pages.isEmpty
              ? null
              : () => _openPlayer(context, detail, i64(detail.pages.first.cid)),
          icon: const Icon(Icons.play_arrow),
          label: const Text('播放'),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.4,
      ),
    );
  }
}

void _openPlayer(BuildContext context, VideoDetailDto detail, int cid) {
  final id = detail.bvid.isNotEmpty ? detail.bvid : 'av${i64(detail.aid)}';
  final title = Uri.encodeComponent(detail.title);
  final bvid = Uri.encodeComponent(detail.bvid);
  context.push(
    '/play/${Uri.encodeComponent(id)}'
    '?cid=$cid&aid=${i64(detail.aid)}&bvid=$bvid&title=$title',
  );
}

String _fmt(int n) {
  if (n >= 100000000) {
    return '${(n / 100000000).toStringAsFixed(1)}亿';
  }
  if (n >= 10000) {
    return '${(n / 10000).toStringAsFixed(1)}万';
  }
  return '$n';
}

String _formatDuration(int ms) {
  if (ms <= 0) return '0:00';
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}
