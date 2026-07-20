# Repository Guidelines

## Project Structure & Module Organization

NextPili is a desktop-first Bilibili client: Rust core + Flutter UI via flutter_rust_bridge 2.11.

```text
crates/domain   # pure domain types (no IO)
crates/auth     # cookies, WBI, AppSign, buvid
crates/http     # Bilibili HTTP client
crates/store    # local persistence
crates/media    # playback / danmaku normalization
crates/core     # FFI surface + use-case orchestration
app/            # Flutter shell (Riverpod, go_router)
docs/           # architecture, design, API, UX
scripts/        # codegen and test helpers
```

Flutter feature code lives under `app/lib/features/`; shared UI under `app/lib/core/`. FRB bindings are under `app/lib/bridge/` and `crates/core/src/api/`. Design docs: `docs/README.md` (portal), `docs/writing.md` (style), `docs/architecture.md`, `docs/design/`, `docs/api/`, `docs/ux/`.

## Build, Test, and Development Commands

```bash
cargo test --workspace          # or ./scripts/test-rust.sh
./scripts/codegen.sh            # regenerate FRB after crates/core/src/api changes
cd app && flutter pub get
cd app && flutter run -d linux  # windows / macos as available
cd app && flutter analyze
```

Toolchain: Rust stable (edition 2024, rustfmt + clippy), Flutter ≥ 3.41. Install FRB codegen: `cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked`. Enable desktop with `flutter config --enable-linux-desktop`.

## Coding Style & Naming Conventions

- **Rust**: rustfmt defaults; run `cargo fmt` / `cargo clippy --workspace`. Crates use `snake_case` modules; domain stays IO-free.
- **Dart**: `flutter_lints`; 2-space indent; `snake_case` files, `PascalCase` types, `camelCase` members. Prefer feature folders over deep shared dumps.
- Keep modules single-responsibility; prefer new nearby files over growing oversized modules. Public APIs stay small.

## Testing Guidelines

- Rust: unit/integration tests beside crates; run `cargo test --workspace`.
- Flutter: `flutter_test` under `app/test/`; run `cd app && flutter test`.
- Name tests after behavior (`*_test.rs`, `*_test.dart`). Cover pure domain logic first; mock IO at crate boundaries.

## Commit & Pull Request Guidelines

History uses short, imperative subjects (e.g. `Initial commit: NextPili skeleton (review-only)`). Prefer Conventional Commit style when practical: `feat:`, `fix:`, `docs:`, `refactor:`.

PRs should include: purpose and scope, linked issue, test plan (`cargo test` / `flutter test` / device notes), and UI screenshots for shell changes. Do not commit generated noise unless codegen output is intentionally updated via `./scripts/codegen.sh`.

## Security & License Tips

License is **UNLICENSED / review-only** — no production use, redistribution, or commercial use without authorization. Never commit secrets, cookies, or user tokens. Respect Bilibili ToS and third-party dependency licenses.

## Agent-Specific Notes

- Respect crate boundaries: `domain` has no IO; `core` orchestrates and exposes FFI.
- After API surface edits in `crates/core/src/api`, run `./scripts/codegen.sh`.
- Prefer `rtk`-prefixed shell commands when available to reduce tool noise.
