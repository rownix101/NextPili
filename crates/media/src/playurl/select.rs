//! Default stream selection and ordering.

use crate::source::{Stream, StreamId};
use domain::quality::pick_quality;
use domain::classify_video_codec;
use domain::{pick_best_codec_stream, video_codec_score, HwDecodeCaps, QualityQn};

use super::labels::{
    audio_standard_rank, AUDIO_QN_192K, AUDIO_ROLE_DOLBY, AUDIO_ROLE_HIRES, AUDIO_ROLE_STANDARD,
};

pub(super) fn sort_video_streams_for_caps(streams: &mut [Stream], hw_caps: HwDecodeCaps) {
    streams.sort_by(|a, b| {
        let qn = b.qn.unwrap_or(0).cmp(&a.qn.unwrap_or(0));
        if qn != std::cmp::Ordering::Equal {
            return qn;
        }
        let sa = video_codec_score(classify_video_codec(&a.codec), hw_caps);
        let sb = video_codec_score(classify_video_codec(&b.codec), hw_caps);
        sb.cmp(&sa)
            .then_with(|| b.bandwidth.cmp(&a.bandwidth))
            .then_with(|| a.id.cmp(&b.id))
    });
}

pub(super) fn pick_default_video(
    streams: &[Stream],
    preferred_qn: Option<u32>,
    hw_caps: HwDecodeCaps,
) -> StreamId {
    if streams.is_empty() {
        return String::new();
    }
    let qns: Vec<QualityQn> = streams
        .iter()
        .filter_map(|s| s.qn.map(QualityQn))
        .collect();
    let pref = preferred_qn.unwrap_or(80);
    if let Some(pick) = pick_quality(&qns, QualityQn(pref), None) {
        let same: Vec<&Stream> = streams
            .iter()
            .filter(|x| x.qn == Some(pick.get()))
            .collect();
        if let Some(best) = pick_best_codec_stream(
            &same,
            hw_caps,
            |s| s.codec.as_str(),
            |s| s.bandwidth,
            |s| s.id.as_str(),
        ) {
            return best.id.clone();
        }
    }
    streams[0].id.clone()
}

/// Default audio: **192K if present**, else highest **standard** track.
/// Dolby / Hi-Res are never auto-selected (opt-in menu only).
pub(super) fn pick_default_audio(streams: &[Stream]) -> StreamId {
    if streams.is_empty() {
        return String::new();
    }

    // Exact 192K.
    if let Some(s) = streams.iter().find(|s| {
        s.qn == Some(AUDIO_QN_192K) && s.role.as_deref() != Some(AUDIO_ROLE_DOLBY)
    }) {
        return s.id.clone();
    }

    // Highest standard (non-dolby, non-hires).
    let mut standard: Vec<&Stream> = streams
        .iter()
        .filter(|s| {
            let role = s.role.as_deref().unwrap_or(AUDIO_ROLE_STANDARD);
            role == AUDIO_ROLE_STANDARD
        })
        .collect();
    if !standard.is_empty() {
        standard.sort_by_key(|s| {
            let qn = s.qn.unwrap_or(0);
            std::cmp::Reverse(audio_standard_rank(qn, s.bandwidth))
        });
        return standard[0].id.clone();
    }

    // Only special tracks available — pick first (rare).
    streams[0].id.clone()
}

pub(super) fn dedupe_audio_streams(streams: Vec<Stream>) -> Vec<Stream> {
    use std::collections::HashMap;
    let mut best: HashMap<u32, Stream> = HashMap::new();
    let mut no_qn = Vec::new();
    for s in streams {
        match s.qn {
            Some(q) => {
                best.entry(q)
                    .and_modify(|cur| {
                        if s.bandwidth > cur.bandwidth {
                            *cur = s.clone();
                        }
                    })
                    .or_insert(s);
            }
            None => no_qn.push(s),
        }
    }
    let mut out: Vec<Stream> = best.into_values().collect();
    out.extend(no_qn);
    // Menu order: standard high→low, then Dolby, then Hi-Res.
    out.sort_by(|a, b| {
        let ra = a.role.as_deref().unwrap_or(AUDIO_ROLE_STANDARD);
        let rb = b.role.as_deref().unwrap_or(AUDIO_ROLE_STANDARD);
        let order = |r: &str| match r {
            AUDIO_ROLE_STANDARD => 0,
            AUDIO_ROLE_DOLBY => 1,
            AUDIO_ROLE_HIRES => 2,
            _ => 3,
        };
        order(ra)
            .cmp(&order(rb))
            .then_with(|| {
                let qa = a.qn.unwrap_or(0);
                let qb = b.qn.unwrap_or(0);
                audio_standard_rank(qb, b.bandwidth).cmp(&audio_standard_rank(qa, a.bandwidth))
            })
    });
    out
}
