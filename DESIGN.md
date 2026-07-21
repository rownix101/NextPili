# DESIGN.md — Player settings overlay

> Status: implementation contract for the right-side player settings panel  
> Governing system: [docs/ux](docs/ux/README.md) · [design-system](docs/ux/design-system.md) · [interaction](docs/ux/interaction.md) · [motion](docs/ux/motion.md) · [flutter design](docs/design/flutter.md)  
> This file does **not** replace `docs/ux/*`; it records screenshot-derived geometry and behavior for one surface.

---

## 0. Research log

| Lane | Deliverable |
|------|-------------|
| Repo UX docs | Liquid Glass chrome/menus; **no** `BackdropFilter` over video texture; player tokens always dark; Lucide/`AppIcons`; 4dp grid; motion tokens |
| Existing player code | `PlayerPane` chrome policy; bottom quality/speed/subtitle menus; `PlayerColors.chromeGlass`; Escape on fullscreen host |
| Screenshot reference | Dark cinematic playback; compact dark rounded **right-side** settings popover; toggle rows above value/chevron rows |

---

## 1. Reference source

- **Visual contract:** user-supplied dark player screenshot (right-side settings popover).
- **Intent:** match geometry, density, row anatomy, and material *feel* — not third-party branding or non-product copy.
- **Product labels:** NextPili localized strings only (`app_en.arb` / `app_zh.arb`).

Row order (top → bottom):

1. Stable volume — switch (local stub)
2. Voice boost — switch (local stub)
3. Ambient mode — switch (local stub)
4. Subtitles / CC — value + chevron (wired to existing subtitle selection)
5. Sleep timer — value + chevron (local stub)
6. Playback speed — value + chevron (wired to existing speed selection)
7. Quality — value + chevron (wired to existing quality selection)

---

## 2. Dark overlay material

| Token / role | Value | Notes |
|--------------|-------|--------|
| Settings tray | `GlassContainer` + `GlassPanel.playerChromeSettings(chromeGlass)` | Liquid Glass tray (package shader glass, **not** Flutter `BackdropFilter`) |
| `player.chromeGlass` | existing `glass.tint.player` | Tint for settings tray **and** bottom **icon pills** |
| `player.menuSurface` | `#121826` @ ~90% | Fallback / nested opaque chips if glass is degraded |
| `player.controlFg` | near-white | Row icons + primary labels |
| `player.controlFgMuted` | white ~70% | Secondary values, chevrons |
| `player.progressPlayed` / accent | Sky accent | Switch track active |
| Border | white @ ~8% | Optional hairline under glass if contrast needs help |

**Hard rule:** never Flutter `BackdropFilter` over the media_kit video texture (desktop HW textures are not sampleable). Package Liquid Glass chrome over the player is allowed for settings tray + icon pills only — **not** a full-width frosted bar over the seek track.

**Bottom chrome shape:** soft scrim + bare seek/danmaku; Liquid Glass **pills** only around transport and action icon clusters.

---

## 3. Dimensions / radius / spacing / type

| Token | Value | Use |
|-------|-------|-----|
| Panel width | **280** (clamp 240–320 on narrow) | Fixed preferred width |
| Corner radius | `AppShapes.md` **12** | Matches design-system §4.2 |
| Panel padding | `AppSpacing.sm` **8** vertical / horizontal | Inner inset |
| Row height | **44** (4dp grid) | Comfortable desktop hit target ≥40 |
| Icon size | `AppIcons.sm` **20** | Leading row icons |
| Icon ↔ label gap | `AppSpacing.sm` **8** | |
| Label ↔ trailing gap | `AppSpacing.sm` **8** | |
| Row horizontal padding | `AppSpacing.sm`–`12` | 8–12 |
| Type — row label | 14 / w500 / `controlFg` | |
| Type — trailing value | 13 / w400 / `controlFgMuted` | |
| Type — switch | platform Switch, accent track | |
| Chevron | `AppIcons.chevronRight` 16–18 muted | Value rows only |

Vertical placement: right edge, vertically centered in the video area between top chrome and bottom chrome; **8–12** margin from the player right edge.

---

## 4. Responsive behavior

| Surface width | Behavior |
|---------------|----------|
| ≥ 520 | Full panel width 280, right-aligned |
| < 520 | Width `min(280, surfaceWidth − 24)`; keep right margin 8–12 |
| Mini player | Settings control **hidden** / not applicable (mini chrome only) |
| Fullscreen | Same panel; chrome held open while panel is visible |

Panel does not cover the entire video; chrome remains visible and interactive.

---

## 5. Interaction / dismiss

| Action | Result |
|--------|--------|
| Settings / sliders control | **Toggles** panel open/closed |
| Open panel | Force chrome visible; hold auto-hide while open |
| Tap outside panel (video barrier) | Dismiss panel; chrome hide timer resumes |
| Escape | Dismiss panel **first**; only then fall through to fullscreen exit / navigation |
| Quality / subtitle / sleep rows | Navigate to nested **options list** (shared chrome with quality); no PopupMenu |
| **Speed row** | Nested speed sub-panel (stepper + chips; same plate) |
| Toggle rows (stable volume, voice boost, ambient) | Flip local UI state only — **no** media effect |
| Sleep timer options | Off / 15 / 30 / 60 min / **End of video** — local UI only; **no** timer engine yet |
| Bottom-row quality/speed/subtitle | **Kept** — no behavior regression (bottom speed remains PopupMenu) |

Focus order: settings trigger → panel rows (top to bottom) → dismiss restores prior focus.  
When speed sub-panel is open: back control → rate readout → decrement → slider → increment → chips.

---

## 5.1 Nested playback-speed sub-panel (screenshot contract)

**Visual reference:** user-supplied dark translucent speed panel (header/back; large centered rate; circular − / + around a light discrete slider; quick-select chips below). Match information hierarchy and control anatomy — **not** third-party branding or copy.

### Geometry (inside the same `menuSurface` plate, width unchanged)

| Region | Layout | Token / size |
|--------|--------|--------------|
| Header | Leading **back** (icon-only) + title `playerSpeed` | Hit ≥40; icon `AppIcons.chevronLeft` 20; title 14 / w500 / `controlFg` |
| Current rate | **Centered**, one line | **28** / w600 / `controlFg`; tabular figures preferred; label via `playerSpeedLabel(rate)` |
| Stepper row | Circular **decrement** · **discrete slider** · circular **increment** | Circle buttons **36** diameter; icon 18; horizontal padding `AppSpacing.sm` |
| Slider track | Light/white on dark plate | Active/inactive from `controlFg` @ high/low alpha; thumb near-white; track height **3–4** |
| Chips | **Single row** of equal-width chips under stepper | Height **32**; radius `AppShapes.sm` **8**; gap **4** (`AppSpacing.xs`); **7** options + gaps fit in content width (**280 − 16**); no wrap, no horizontal overflow |
| Vertical rhythm | Header → rate → stepper → chips | Section gaps `AppSpacing.sm`–`md` (8–16); outer padding `AppSpacing.sm` |

### Discrete rates & index mapping

Canonical list: **`MediaKitPlayerAdapter.speedOptions`**  
`[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]` — **do not fork** a second option list.

| Concern | Rule |
|---------|------|
| Slider domain | Integer **index** `0 … n−1` (not raw rate). `Slider` `min=0`, `max=n−1`, `divisions=n−1` |
| Current index | Exact match on `rate` in options; if missing, **nearest** option by absolute distance (stable on ties: lower index) |
| Decrement / increment | Move index by ±1; **clamp** at ends — no wrap; disabled (or no-op) at bounds |
| Chip select | Sets that option’s rate immediately |
| Apply path | **Only** `onSpeed(double)` — same callback as before; no direct adapter calls from the panel |
| Label | Always `playerSpeedLabel(rate)` for chips, center, and trailing main-list value |

### Interaction

| Action | Result |
|--------|--------|
| Tap main-list Speed row | Replace list body with nested speed view (same plate; no PopupMenu) |
| Back (header) | Return to main settings list; **do not** change rate |
| − / + | Step one discrete option; call `onSpeed` when index changes |
| Slider drag / tap | Snap to nearest division index; call `onSpeed` with that option |
| Chip | Select rate; call `onSpeed`; visual selected state = current index |
| Outside / Escape | Still dismisses **entire** settings panel (existing host behavior) |

Bottom chrome speed PopupMenu is **unchanged** and independent of this nested view.

### Motion (sub-panel only)

| Event | Token | Notes |
|-------|-------|-------|
| List ↔ speed | Cross-fade and/or slight horizontal slide (**≤8px**) | `AppDuration.medium1`–`medium2` (**200–250ms**), decelerate in / accelerate out |
| Reduce motion | `MediaQuery.disableAnimations` / `appReduceMotion` | Instant swap or fade ≤ `AppDuration.short2` — **no** slide |
| Rate / chip change | No decorative bounce | Optional opacity ≤ short2 only if needed for selection |

No loops; no motion over the video texture.

### Semantics

| Control | Semantics |
|---------|-----------|
| Sub-panel | Container; title / label from `playerSpeed` |
| Back | Button; `back` (existing) + tooltip |
| Current rate | Live region / value text (not a button) |
| Decrement | Button; `playerSpeedDecrease` |
| Increment | Button; `playerSpeedIncrease` |
| Slider | `playerSpeedSlider` + current value string |
| Chip | Button; name = speed label (e.g. `1.25x`); selected state when current |

---

## 6. Motion

| Event | Token | Curve |
|-------|-------|-------|
| Panel enter | fade + slide from right **8–12px** | `AppDuration.medium1`–`medium3` (**200–300ms**), `AppEasing.standardDecelerate` |
| Panel exit | fade + slide out | same duration, `AppEasing.standardAccelerate` |
| Nested speed enter/exit | §5.1 | same token family |
| Reduce motion | `MediaQuery.disableAnimations` → fade only or ≤ `AppDuration.short2` | via `appMotionDuration` |

No decorative loops; motion only for open/close and list ↔ nested speed.

---

## 7. Keyboard / focus / accessibility

| Requirement | Detail |
|-------------|--------|
| Settings trigger | Icon-only + **Tooltip** + **Semantics** label (`playerSettings`) |
| Panel | `Semantics(container: true, label: playerSettings)` |
| Switches | Semantics from `Switch`; labels from row text |
| Value rows | Button semantics with name + current value |
| Nested speed | §5.1 semantics table; icon-only −/+ must not rely on glyph alone |
| Escape | Closes panel before fullscreen exit |
| Contrast | Light text on dark plate; switch active uses accent; selected chip uses accent track |

---

## 8. Scope / debt

| Item | Status |
|------|--------|
| Quality / subtitle selection | **Real** — PopupMenu + existing callbacks |
| Speed (settings panel) | **Real** — nested sub-panel → `onSpeed` only |
| Speed (bottom chrome) | **Unchanged** PopupMenu |
| Stable volume, Voice boost, Ambient mode | **Local UI stubs only** — do not claim audio pipeline changes |
| Sleep timer | **Local UI stub** — stores minutes; no auto-pause yet |
| BackdropFilter / Liquid Glass over video | **Out of scope** — solid translucent token plate |
| Persist stubs to store | Future; not this slice |
| Material 3 restyle of player chrome | Forbidden |

---

## 9. Implementation map

| File | Role |
|------|------|
| `app/lib/features/player/player_settings_local_state.dart` | Pure local stub state |
| `app/lib/features/player/player_settings_overlay.dart` | Panel shell; main list ↔ nested speed navigation |
| `app/lib/features/player/player_settings_list.dart` | Main settings list body |
| `app/lib/features/player/player_settings_speed.dart` | Discrete index helpers |
| `app/lib/features/player/player_settings_speed_panel.dart` | Nested speed composition |
| `app/lib/features/player/player_settings_speed_widgets.dart` | Speed header / step / chips |
| `app/lib/features/player/player_settings_rows.dart` | Switch / value menu / nav rows |
| `app/lib/features/player/player_pane.dart` | Visibility, barrier, Escape, chrome hold |
| `app/lib/features/player/player_bottom_chrome.dart` | Settings trigger + bottom speed PopupMenu |
| `app/lib/core/theme/player_colors.dart` | `menuSurface` token |
| `app/lib/core/icons/app_icons.dart` | Sliders / row / −+ icons |
| `app/lib/l10n/app_*.arb` | Localized labels |
| `app/test/player_settings_*_test.dart` | Pure state + widget tests |

---

## 10. Acceptance checklist

- [ ] Panel appears on the **right** when settings control is pressed
- [ ] Matches compact dark translucent rounded popover geometry
- [ ] Icon + label on every row; switches then value/chevron rows
- [ ] Speed row opens **nested** speed sub-panel (not PopupMenu); back returns to list
- [ ] Nested panel: centered rate, − / discrete slider / +, chips; rates from `speedOptions` only via `onSpeed`
- [ ] Quality / subtitle still work via existing callbacks; **bottom** speed menu remains
- [ ] Four stubs are local only
- [ ] Outside tap + Escape dismiss; chrome stays while open
- [ ] 200–300ms tokenized motion; reduce-motion honored (incl. nested swap)
- [ ] Speed chips: single row of 7 at 280dp plate; no wrap / no horizontal overflow
- [ ] No `BackdropFilter`, no raw magic colors/durations in feature code
- [ ] `flutter analyze` + focused tests pass
