//! Playback heartbeat supervisor (interval report, non-fatal).

use auth::Account;
use http::{now_unix, BiliClient, HeartbeatParams, VideoApi};
use parking_lot::Mutex;
use std::time::Duration;
use tokio::task::JoinHandle;

const INTERVAL: Duration = Duration::from_secs(15);

#[derive(Debug, Clone)]
pub struct PlayContext {
    pub aid: i64,
    pub bvid: String,
    pub cid: i64,
}

struct ActiveSession {
    handle: JoinHandle<()>,
}

/// Process-scoped supervisor: at most one active heartbeat task.
#[derive(Default)]
pub struct HeartbeatSupervisor {
    active: Mutex<Option<ActiveSession>>,
}

impl HeartbeatSupervisor {
    pub fn new() -> Self {
        Self {
            active: Mutex::new(None),
        }
    }

    /// Start heartbeat for a play session (replaces any previous session).
    pub fn start(
        &self,
        http: BiliClient,
        account: Option<Account>,
        buvid3: String,
        ctx: PlayContext,
    ) {
        self.stop();

        let start_ts = now_unix();
        let mid = account.as_ref().map(|a| a.mid.get()).unwrap_or(0);

        let handle = tokio::spawn(async move {
            // Start event
            let _ = VideoApi::heartbeat(
                &http,
                account.as_ref(),
                Some(buvid3.as_str()),
                &HeartbeatParams {
                    aid: ctx.aid,
                    bvid: ctx.bvid.clone(),
                    cid: ctx.cid,
                    mid,
                    played_time: 0,
                    play_type: 1,
                    start_ts,
                },
            )
            .await;

            let mut elapsed = 0i64;
            loop {
                tokio::time::sleep(INTERVAL).await;
                elapsed += INTERVAL.as_secs() as i64;
                let _ = VideoApi::heartbeat(
                    &http,
                    account.as_ref(),
                    Some(buvid3.as_str()),
                    &HeartbeatParams {
                        aid: ctx.aid,
                        bvid: ctx.bvid.clone(),
                        cid: ctx.cid,
                        mid,
                        played_time: elapsed,
                        play_type: 0,
                        start_ts,
                    },
                )
                .await;
            }
        });

        *self.active.lock() = Some(ActiveSession { handle });
    }

    /// Abort heartbeat task (best-effort end event not sent if task aborted mid-flight).
    pub fn stop(&self) {
        if let Some(session) = self.active.lock().take() {
            session.handle.abort();
        }
    }
}

