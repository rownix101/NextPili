import 'package:flutter/material.dart';

import '../../bridge/core_api.dart';
import '../../core/haptics/haptics.dart';
import '../../core/theme/player_colors.dart';
import '../../l10n/l10n.dart';
import '../video/engagement_bar.dart' show ensureLoggedIn;
import '../../core/widgets/app_snack_bar.dart';

/// PiliPlus-aligned danmaku report reasons (`ReportOptions.danmakuReport`).
const Map<int, String> kDanmakuReportReasonsZh = {
  1: '违法违禁',
  2: '色情低俗',
  3: '赌博诈骗',
  4: '人身攻击',
  5: '侵犯隐私',
  6: '垃圾广告',
  7: '引战',
  8: '剧透',
  9: '恶意刷屏',
  10: '视频无关',
  12: '青少年不良信息',
  13: '违法信息外链',
  0: '其它',
};

const Map<int, String> kDanmakuReportReasonsEn = {
  1: 'Illegal',
  2: 'Pornography',
  3: 'Gambling / fraud',
  4: 'Personal attack',
  5: 'Privacy',
  6: 'Spam',
  7: 'Flame war',
  8: 'Spoiler',
  9: 'Flooding',
  10: 'Off-topic',
  12: 'Harmful to minors',
  13: 'Illegal external link',
  0: 'Other',
};

/// Long-press sheet: like + report for one danmaku.
Future<void> showDanmakuActions(
  BuildContext context, {
  required DanmakuItemDto item,
  required int cid,
}) async {
  final id = i64(item.id);
  if (id <= 0) return;
  final l10n = context.l10n;
  final colors = PlayerColors.of(context);
  final locale = Localizations.localeOf(context).languageCode;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.chromeGlass,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                item.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.controlFg, fontSize: 14),
              ),
            ),
            ListTile(
              leading: Icon(Icons.thumb_up_outlined, color: colors.controlFg),
              title: Text(
                l10n.playerDanmakuLike,
                style: TextStyle(color: colors.controlFg),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _like(context, cid: cid, dmid: id);
              },
            ),
            ListTile(
              leading: Icon(Icons.flag_outlined, color: colors.controlFg),
              title: Text(
                l10n.playerDanmakuReport,
                style: TextStyle(color: colors.controlFg),
              ),
              onTap: () async {
                Navigator.of(ctx).pop();
                await _report(
                  context,
                  cid: cid,
                  dmid: id,
                  locale: locale,
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

Future<void> _like(
  BuildContext context, {
  required int cid,
  required int dmid,
}) async {
  if (!await ensureLoggedIn(context)) return;
  if (!context.mounted) return;
  final l10n = context.l10n;
  try {
    await CoreApi.instance.danmakuLike(oid: cid, dmid: dmid, like: true);
    await Haptics.success();
    if (!context.mounted) return;
    AppSnackBar.show(context, message: l10n.playerDanmakuLiked);
  } catch (e) {
    if (!context.mounted) return;
    await Haptics.error();
    if (!context.mounted) return;
    AppSnackBar.show(context, message: errorMessage(e, context.l10n));
  }
}

Future<void> _report(
  BuildContext context, {
  required int cid,
  required int dmid,
  required String locale,
}) async {
  if (!await ensureLoggedIn(context)) return;
  if (!context.mounted) return;
  final l10n = context.l10n;
  final colors = PlayerColors.of(context);
  final reasons =
      locale.startsWith('zh') ? kDanmakuReportReasonsZh : kDanmakuReportReasonsEn;

  final reason = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: colors.chromeGlass,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in reasons.entries)
              ListTile(
                title: Text(
                  e.value,
                  style: TextStyle(color: colors.controlFg),
                ),
                onTap: () => Navigator.of(ctx).pop(e.key),
              ),
          ],
        ),
      );
    },
  );
  if (reason == null || !context.mounted) return;

  String content = '';
  if (reason == 0) {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.playerDanmakuReportOther),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.playerDanmakuReportOtherHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.playerDanmakuReportSubmit),
            ),
          ],
        );
      },
    );
    content = controller.text.trim();
    controller.dispose();
    if (ok != true || !context.mounted) return;
  }

  try {
    final code = await CoreApi.instance.danmakuReport(
      cid: cid,
      dmid: dmid,
      reason: reason,
      content: content,
    );
    await Haptics.success();
    if (!context.mounted) return;
    final msg = switch (code) {
      0 => l10n.playerDanmakuReportOk,
      -4 => l10n.playerDanmakuReportRateLimit,
      -5 => l10n.playerDanmakuReportDup,
      _ => l10n.playerDanmakuReportOk,
    };
    AppSnackBar.show(context, message: msg);
  } catch (e) {
    if (!context.mounted) return;
    await Haptics.error();
    if (!context.mounted) return;
    AppSnackBar.show(context, message: errorMessage(e, context.l10n));
  }
}
