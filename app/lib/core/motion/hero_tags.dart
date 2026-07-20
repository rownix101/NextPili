/// Stable [Hero] tags — docs/ux/motion.md §4.4.
///
/// Tag must match list card ↔ detail destination; unique per visible route.
abstract final class AppHeroTags {
  /// Cover morph for video list card → watch page.
  /// [videoId] is the same string used in `/video/:id` (bvid or `av{aid}`).
  static String videoCover(String videoId) => 'np.video.cover.$videoId';
}
