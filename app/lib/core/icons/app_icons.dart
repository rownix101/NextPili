import 'package:flutter/widgets.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

/// Lucide semantic map — design-system §7.
/// Prefer these over Material [Icons.*].
abstract final class AppIcons {
  // Nav
  static const IconData home = LucideIcons.house;
  static const IconData settings = LucideIcons.settings;
  static const IconData search = LucideIcons.search;
  static const IconData user = LucideIcons.user;
  static const IconData users = LucideIcons.users;

  // Media
  static const IconData play = LucideIcons.play;
  static const IconData pause = LucideIcons.pause;
  static const IconData playCircle = LucideIcons.circle_play;
  static const IconData fullscreen = LucideIcons.maximize;
  static const IconData fullscreenExit = LucideIcons.minimize;
  static const IconData volume = LucideIcons.volume_2;
  static const IconData volumeMute = LucideIcons.volume_x;
  static const IconData danmaku = LucideIcons.message_square_text;
  static const IconData movie = LucideIcons.clapperboard;
  static const IconData imageBroken = LucideIcons.image_off;
  static const IconData highQuality = LucideIcons.hd;

  // Actions
  static const IconData like = LucideIcons.thumbs_up;
  static const IconData comment = LucideIcons.message_circle;
  static const IconData star = LucideIcons.star;
  static const IconData coin = LucideIcons.circle_dollar_sign;
  static const IconData share = LucideIcons.share_2;
  static const IconData copy = LucideIcons.copy;
  static const IconData refresh = LucideIcons.refresh_cw;
  static const IconData logout = LucideIcons.log_out;
  static const IconData login = LucideIcons.log_in;
  static const IconData externalLink = LucideIcons.external_link;
  static const IconData shield = LucideIcons.shield;
  static const IconData sms = LucideIcons.message_square;
  static const IconData qrCode = LucideIcons.qr_code;
  static const IconData chevronRight = LucideIcons.chevron_right;
  static const IconData chevronLeft = LucideIcons.chevron_left;
  static const IconData arrowLeft = LucideIcons.arrow_left;
  static const IconData close = LucideIcons.x;
  static const IconData more = LucideIcons.ellipsis;
  static const IconData plus = LucideIcons.plus;
  static const IconData check = LucideIcons.check;

  // Status
  static const IconData cloudOff = LucideIcons.cloud_off;
  static const IconData alert = LucideIcons.triangle_alert;
  static const IconData info = LucideIcons.info;
  static const IconData inbox = LucideIcons.inbox;
  static const IconData wifiOff = LucideIcons.wifi_off;
  static const IconData lock = LucideIcons.lock;
  static const IconData proxy = LucideIcons.shield_check;

  // Sizes — design-system §7.2
  static const double xs = 16;
  static const double sm = 20;
  static const double md = 24;
  static const double lg = 28;
  static const double xl = 32;
}
