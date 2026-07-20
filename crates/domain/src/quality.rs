use crate::id::QualityQn;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AudioTrack {
    pub id: String,
    pub language: Option<String>,
    pub is_ai: bool,
}

/// Pick stream quality: preferred if available, else highest ≤ preferred, else lowest.
pub fn pick_quality(
    available: &[QualityQn],
    preferred: QualityQn,
    max: Option<QualityQn>,
) -> Option<QualityQn> {
    if available.is_empty() {
        return None;
    }

    let mut sorted: Vec<QualityQn> = available
        .iter()
        .copied()
        .filter(|q| max.map(|m| q.get() <= m.get()).unwrap_or(true))
        .collect();
    if sorted.is_empty() {
        // Cap filtered everything — fall back to lowest overall.
        sorted = available.to_vec();
    }
    sorted.sort_by_key(|q| q.get());

    if sorted.contains(&preferred) {
        return Some(preferred);
    }

    sorted
        .iter()
        .copied()
        .filter(|q| q.get() <= preferred.get())
        .max_by_key(|q| q.get())
        .or_else(|| sorted.first().copied())
}

/// Prefer language match; otherwise first non-AI track; otherwise first track.
pub fn pick_audio_track<'a>(
    tracks: &'a [AudioTrack],
    lang_pref: Option<&str>,
) -> Option<&'a AudioTrack> {
    if tracks.is_empty() {
        return None;
    }
    if let Some(pref) = lang_pref
        && let Some(t) = tracks.iter().find(|t| {
            t.language
                .as_deref()
                .is_some_and(|l| l.eq_ignore_ascii_case(pref))
        })
    {
        return Some(t);
    }
    tracks
        .iter()
        .find(|t| !t.is_ai)
        .or_else(|| tracks.first())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn quality_prefers_exact() {
        let avail = [QualityQn(16), QualityQn(64), QualityQn(80)];
        assert_eq!(
            pick_quality(&avail, QualityQn(64), None),
            Some(QualityQn(64))
        );
    }

    #[test]
    fn quality_falls_down() {
        let avail = [QualityQn(16), QualityQn(32), QualityQn(80)];
        assert_eq!(
            pick_quality(&avail, QualityQn(64), None),
            Some(QualityQn(32))
        );
    }

    #[test]
    fn quality_falls_to_lowest_when_all_higher() {
        let avail = [QualityQn(80), QualityQn(112)];
        assert_eq!(
            pick_quality(&avail, QualityQn(16), None),
            Some(QualityQn(80))
        );
    }

    #[test]
    fn audio_pref_then_non_ai() {
        let tracks = [
            AudioTrack {
                id: "ai".into(),
                language: Some("zh".into()),
                is_ai: true,
            },
            AudioTrack {
                id: "ja".into(),
                language: Some("ja".into()),
                is_ai: false,
            },
            AudioTrack {
                id: "zh".into(),
                language: Some("zh".into()),
                is_ai: false,
            },
        ];
        assert_eq!(pick_audio_track(&tracks, Some("ja")).unwrap().id, "ja");
        assert_eq!(pick_audio_track(&tracks, Some("en")).unwrap().id, "ja");
    }
}
