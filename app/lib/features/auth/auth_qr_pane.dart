import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../bridge/core_api.dart';
import '../../core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/shapes.dart';
import '../../core/theme/spacing.dart';
import '../../l10n/l10n.dart';

/// Left QR pane for dual-pane login card.
class AuthQrPane extends StatelessWidget {
  const AuthQrPane({
    super.key,
    required this.busy,
    required this.qrUrl,
    required this.status,
    required this.statusKind,
    required this.onRefresh,
  });

  final bool busy;
  final String? qrUrl;
  final String status;
  final QrStatusKind? statusKind;
  final VoidCallback onRefresh;

  static const double _qrSize = 168;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final l10n = context.l10n;
    final expired = statusKind == QrStatusKind.expired;
    final failed = statusKind == QrStatusKind.error;
    final confirmed = statusKind == QrStatusKind.confirmed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.authQrPanelTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Tooltip(
            message: busy ? l10n.authQrRefreshing : l10n.authQrTapRefresh,
            child: Material(
              color: Colors.white,
              borderRadius: AppShapes.borderMd,
              child: InkWell(
                borderRadius: AppShapes.borderMd,
                onTap: busy ? null : onRefresh,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppShapes.borderMd,
                    border: Border.all(color: colors.borderSubtle),
                  ),
                  child: SizedBox(
                    width: _qrSize + AppSpacing.lg,
                    height: _qrSize + AppSpacing.lg,
                    child: Center(child: _buildQrBody(colors)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            status.isEmpty ? l10n.authQrPanelHint : status,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: confirmed
                  ? colors.success
                  : (expired || failed)
                      ? colors.error
                      : colors.fgSecondary,
              height: 1.4,
            ),
          ),
          if (expired || failed || qrUrl == null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: busy ? null : onRefresh,
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.refresh, size: 16),
              label: Text(
                busy
                    ? l10n.authQrRefreshing
                    : (expired || failed || qrUrl == null)
                        ? l10n.refresh
                        : l10n.authQrReacquire,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQrBody(AppColors colors) {
    if (busy && (qrUrl == null || qrUrl!.isEmpty)) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final url = qrUrl;
    if (url == null || url.isEmpty) {
      return Icon(AppIcons.qrCode, size: 40, color: colors.fgMuted);
    }
    Widget qr = QrImageView(
      data: url,
      version: QrVersions.auto,
      size: _qrSize,
      backgroundColor: Colors.white,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );
    if (statusKind == QrStatusKind.expired ||
        statusKind == QrStatusKind.error) {
      qr = ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: Opacity(opacity: 0.35, child: qr),
      );
    }
    return qr;
  }
}

