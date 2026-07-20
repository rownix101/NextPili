/// Stable [Hero] tags — docs/ux/motion.md §4.4.
///
/// Tag must match list card ↔ detail destination; unique per visible route.
/// When the same [videoId] appears more than once in a list, pass a distinct
/// [slot] (e.g. grid index) and forward that full tag via `GoRouter` `extra`.
abstract final class AppHeroTags {
  /// Cover morph for video list card → watch page.
  ///
  /// [videoId] is the same string used in `/video/:id` (bvid or `av{aid}`).
  /// [slot] disambiguates duplicate ids in one route subtree.
  static String videoCover(String videoId, {Object? slot}) {
    if (slot == null) return 'np.video.cover.$videoId';
    return 'np.video.cover.$videoId#$slot';
  }
}
